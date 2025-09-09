defmodule Mix.Tasks.Metrics.Bench do
  use Mix.Task

  @shortdoc "Simple ingestion benchmark"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")
    Benchee.run(%{
      "ingest-10k" => fn -> ingest(10_000) end
    })
  end

  defp ingest(n) do
    now = DateTime.utc_now()
    for i <- 1..n do
      MetricsEngine.record_metric(%{
        metric_name: "bench.latency",
        value: rem(i, 250) * 1.0,
        timestamp: now,
        tags: %{"svc" => Integer.to_string(rem(i, 5))}
      })
    end
  end
end
