defmodule MetricsEngine.Application do
  @moduledoc false
  use Application

  @registry MetricsEngine.Registry
  @top_sup MetricsEngine.Supervisor

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, name: MetricsEngine.WorkerSupervisor, strategy: :one_for_one},
      MetricsEngine.EtsStarter
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: @top_sup)
  end
end
