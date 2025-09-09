defmodule MetricsEngine.EtsStarter do
  @moduledoc false
  use GenServer

  @table :metrics_engine_aggregates

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true, write_concurrency: true])
    {:ok, %{}}
  end
end
