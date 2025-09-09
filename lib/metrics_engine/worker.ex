defmodule MetricsEngine.Worker do
  @moduledoc false
  use GenServer

  alias MetricsEngine.{Windows, TagKey}

  @registry MetricsEngine.Registry
  @sup MetricsEngine.WorkerSupervisor
  @table :metrics_engine_aggregates

  ## Public API

  def ensure_started(metric, window) do
    name = via(metric, window)
    case GenServer.whereis(name) do
      nil ->
        spec = %{id: {__MODULE__, metric, window}, start: {__MODULE__, :start_link, [metric, window]}, restart: :transient}
        case DynamicSupervisor.start_child(@sup, spec) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, :already_present} -> :ok
          other -> other
        end
      _pid -> :ok
    end
  end

  def record({metric, window}, value, ts, tags) do
    GenServer.cast(via(metric, window), {:record, value, ts, tags})
  end

  def via(metric, window), do: {:via, Registry, {@registry, {metric, window}}}

  ## GenServer

  def start_link(metric, window) do
    GenServer.start_link(__MODULE__, {metric, window}, name: via(metric, window))
  end

  @impl true
  def init({metric, window}) do
    state = %{
      metric: metric,
      window: window,
      win_secs: Windows.seconds(window),
      groups: %{} # tag_key => %{q: :queue.queue(), sum: float, count: non_neg_integer, min: float|nil, max: float|nil}
    }
    {:ok, state}
  end

  @impl true
  def handle_cast({:record, value, ts, tags}, state) do
    key = TagKey.from_map(tags)
    now = DateTime.utc_now()

    {groups, win_secs} = {state.groups, state.win_secs}
    g = Map.get(groups, key, %{q: :queue.new(), sum: 0.0, count: 0, min: nil, max: nil})

    q1 = :queue.in({ts, value}, g.q)
    sum1 = g.sum + value
    count1 = g.count + 1
    min1 = if is_nil(g.min), do: value, else: min(g.min, value)
    max1 = if is_nil(g.max), do: value, else: max(g.max, value)

    g1 = %{g | q: q1, sum: sum1, count: count1, min: min1, max: max1}
    g2 = prune(g1, now, win_secs)

    groups1 = Map.put(groups, key, g2)
    write_ets(state.metric, state.window, key, g2)

    {:noreply, %{state | groups: groups1}}
  end

  ## Helpers

  defp prune(g, now, win_secs) do
    cutoff = DateTime.add(now, -win_secs, :second)

    prune_loop(g, cutoff)
  end

  defp prune_loop(%{q: q} = g, cutoff) do
    case :queue.out(q) do
      {{:value, {ts, v}}, qrest} ->
        if DateTime.compare(ts, cutoff) == :lt do
          g1 = %{g | q: qrest, sum: g.sum - v, count: g.count - 1}

          g2 =
            cond do
              g1.count == 0 -> %{g1 | min: nil, max: nil}
              g.min == v or g.max == v -> recompute_bounds(g1)
              true -> g1
            end

          prune_loop(g2, cutoff)
        else
          g
        end

      {:empty, _} ->
        g
    end
  end

  defp recompute_bounds(%{q: q} = g) do
    # recompute min/max by scanning queue
    {minv, maxv} =
      :queue.to_list(q)
      |> Enum.reduce({nil, nil}, fn {_ts, v}, {mn, mx} ->
        mn1 = if is_nil(mn), do: v, else: min(mn, v)
        mx1 = if is_nil(mx), do: v, else: max(mx, v)
        {mn1, mx1}
      end)

    %{g | min: minv, max: maxv}
  end

  defp write_ets(_metric, _window, key, %{count: 0}) do
    :ets.delete(@table, {_metric, _window, key})
    :ok
  end

  defp write_ets(metric, window, key, %{count: c, sum: s, min: m, max: x}) do
    :ets.insert(@table, {{metric, window, key}, %{count: c, sum: s, avg: if(c==0, do: nil, else: s / c), min: m, max: x}})
    :ok
  end
end
