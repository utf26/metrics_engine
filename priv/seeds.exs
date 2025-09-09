now = DateTime.utc_now()

Enum.each(1..100, fn i ->
  MetricsEngine.record_metric(%{
    metric_name: "api.response_time",
    value: :rand.uniform() * 300.0,
    timestamp: now,
    tags: %{"service" => "web", "environment" => if(rem(i,2)==0, do: "prod", else: "stg")}
  })
end)
