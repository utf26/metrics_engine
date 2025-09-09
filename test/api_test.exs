defmodule MetricsEngine.ApiTest do
  use ExUnit.Case, async: false

  setup do
    :ok = MetricsEngine.start()
    :ok
  end

  test "records and aggregates basic metrics" do
    ts = DateTime.utc_now()
    :ok = MetricsEngine.record_metric(%{
      metric_name: "api.response_time",
      value: 100.0,
      timestamp: ts,
      tags: %{"service" => "web"}
    })
    :ok = MetricsEngine.record_metric(%{
      metric_name: "api.response_time",
      value: 200.0,
      timestamp: ts,
      tags: %{"service" => "web"}
    })

    # Give mailbox a moment
    Process.sleep(50)

    agg = MetricsEngine.get_aggregations("api.response_time", :one_minute)
    assert agg.count == 2
    assert agg.sum == 300.0
    assert agg.avg == 150.0
    assert agg.min == 100.0
    assert agg.max == 200.0
  end

  test "tag filter works with subset" do
    ts = DateTime.utc_now()
    :ok = MetricsEngine.record_metric(%{
      metric_name: "db.query_time",
      value: 50.0,
      timestamp: ts,
      tags: %{"service" => "api", "env" => "prod"}
    })
    :ok = MetricsEngine.record_metric(%{
      metric_name: "db.query_time",
      value: 70.0,
      timestamp: ts,
      tags: %{"service" => "api", "env" => "stg"}
    })

    # Give mailbox a moment
    Process.sleep(50)

    agg_all = MetricsEngine.get_aggregations("db.query_time", :one_minute)
    assert agg_all.count == 2

    agg_prod = MetricsEngine.get_aggregations("db.query_time", :one_minute, %{"env" => "prod"})
    assert agg_prod.count == 1
    assert agg_prod.sum == 50.0
  end

  test "rolling window expires" do
    # Insert an old sample and a fresh one; old should expire
    old = DateTime.add(DateTime.utc_now(), -120, :second)
    new = DateTime.utc_now()

    :ok = MetricsEngine.record_metric(%{
      metric_name: "cache.hit_rate",
      value: 10.0,
      timestamp: old,
      tags: %{"node" => "a"}
    })
    :ok = MetricsEngine.record_metric(%{
      metric_name: "cache.hit_rate",
      value: 30.0,
      timestamp: new,
      tags: %{"node" => "a"}
    })

    # Give mailbox a moment
    Process.sleep(50)

    agg = MetricsEngine.get_aggregations("cache.hit_rate", :one_minute)
    assert agg.count == 1
    assert agg.sum == 30.0
    assert agg.avg == 30.0
  end
end
