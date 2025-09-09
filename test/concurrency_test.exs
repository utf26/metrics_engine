defmodule MetricsEngine.ConcurrencyTest do
  use ExUnit.Case

  setup do
    :ok = MetricsEngine.start()
    :ok
  end

  test "concurrent ingestion" do
    ts = DateTime.utc_now()

    1..1_000
    |> Task.async_stream(fn i ->
      MetricsEngine.record_metric(%{
        metric_name: "ingest.throughput",
        value: rem(i, 100) * 1.0,
        timestamp: ts,
        tags: %{"part" => Integer.to_string(rem(i, 10))}
      })
    end, max_concurrency: 50, timeout: 30_000)
    |> Stream.run()

    agg = MetricsEngine.get_aggregations("ingest.throughput", :one_minute)
    assert agg.count == 1_000
  end
end
