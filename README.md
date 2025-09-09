# MetricsEngine

Real-time metrics aggregation engine using Elixir/OTP.

## Quick start

```bash
asdf install # or ensure Elixir >= 1.15
mix deps.get
iex -S mix
```

```elixir
# In IEx
MetricsEngine.start()
MetricsEngine.record_metric(%{
  metric_name: "api.response_time",
  value: 150.5,
  timestamp: DateTime.utc_now(),
  tags: %{"service" => "web", "environment" => "prod"}
})

MetricsEngine.get_aggregations("api.response_time", :one_minute)
MetricsEngine.get_aggregations("api.response_time", :five_minute, %{"service" => "web"})
```

## Run tests

```bash
mix test
```

## Benchmark (dev only)

```bash
mix metrics.bench
```
