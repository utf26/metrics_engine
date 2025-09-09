defmodule MetricsEngine.Windows do
  @moduledoc false

  @config Application.compile_env(:metrics_engine, MetricsEngine, [])
  @windows Map.get(@config, :windows, %{one_minute: 60, five_minute: 300, fifteen_minute: 900})

  @spec list() :: [{atom(), pos_integer()}]
  def list, do: Map.to_list(@windows)

  @spec seconds(atom()) :: pos_integer()
  def seconds(win), do: Map.fetch!(@windows, win)
end
