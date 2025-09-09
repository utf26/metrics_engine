defmodule MetricsEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :metrics_engine,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_cli_env: [
        "metrics.bench": :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MetricsEngine.Application, []}
    ]
  end

  defp deps do
    [
      {:stream_data, "~> 0.6.0", only: :test},
      {:benchee, "~> 1.3", only: :dev}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
