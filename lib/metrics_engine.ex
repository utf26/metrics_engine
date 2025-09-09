defmodule MetricsEngine do
  @moduledoc """
  Public API for the metrics engine.
  """

  alias MetricsEngine.{Windows, TagKey, Worker}

  @table :metrics_engine_aggregates

  @spec start() :: :ok | {:error, term()}
  def start do
    case Application.ensure_all_started(:metrics_engine) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  @doc """
  Record a metric event map with keys:
    * :metric_name (string)
    * :value (number)
    * :timestamp (DateTime.t())
    * :tags (map of string=>string)
  """
  @spec record_metric(map()) :: :ok | {:error, term()}
  def record_metric(%{metric_name: metric, value: value, timestamp: ts, tags: tags})
      when is_binary(metric) and is_number(value) and is_map(tags) do
    Windows.list()
    |> Enum.each(fn {window, _secs} ->
      Worker.ensure_started(metric, window)
      Worker.record({metric, window}, value, ts, tags)
    end)

    :ok
  end

  def record_metric(_), do: {:error, :invalid_metric}

  @doc """
  Get aggregations for a metric and window across all tag groups.
  """
  @spec get_aggregations(String.t(), atom()) :: map()
  def get_aggregations(metric, window) when is_binary(metric) and is_atom(window) do
    match_spec = [{{{metric, window, :_}, :_}, [], [:'$_']}]

    :ets.select(@table, match_spec)
    |> Enum.reduce(%{count: 0, sum: 0.0, min: nil, max: nil}, fn {{_m, _w, _key}, v}, acc ->
      merge_aggs(acc, v)
    end)
    |> finalize_avg()
  end

  @doc """
  Get aggregations filtered by a subset of tags.
  """
  @spec get_aggregations(String.t(), atom(), map()) :: map()
  def get_aggregations(metric, window, filter_tags)
      when is_binary(metric) and is_atom(window) and is_map(filter_tags) do
    filter_tags = TagKey.normalize_tags(filter_tags)
    match_spec = [{{{metric, window, :_}, :_}, [], [:'$_']}]

    :ets.select(@table, match_spec)
    |> Enum.reduce(%{count: 0, sum: 0.0, min: nil, max: nil}, fn {{^metric, ^window, key}, v}, acc ->
      if TagKey.superset_key?(key, filter_tags), do: merge_aggs(acc, v), else: acc
    end)
    |> finalize_avg()
  end

  defp merge_aggs(%{count: c1, sum: s1, min: m1, max: x1}, %{count: c2, sum: s2, min: m2, max: x2}) do
    %{
      count: c1 + c2,
      sum: s1 + s2,
      min: min_or(m1, m2),
      max: max_or(x1, x2)
    }
  end

  defp min_or(nil, b), do: b
  defp min_or(a, nil), do: a
  defp min_or(a, b), do: min(a, b)

  defp max_or(nil, b), do: b
  defp max_or(a, nil), do: a
  defp max_or(a, b), do: max(a, b)

  defp finalize_avg(%{count: 0} = _), do: %{count: 0, sum: 0.0, avg: nil, min: nil, max: nil}
  defp finalize_avg(%{count: c, sum: s, min: m, max: x}), do: %{count: c, sum: s, avg: s / c, min: m, max: x}
end
