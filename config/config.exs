import Config

config :metrics_engine, MetricsEngine, %{
  windows: %{
    one_minute: 60,
    five_minute: 300,
    fifteen_minute: 900
  }
}
