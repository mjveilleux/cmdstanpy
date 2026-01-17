defmodule CmdStan.MixProject do
  use Mix.Project

  def project do
    [
      app: :cmdstan,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ssl, :inets],
      mod: {CmdStan.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 2.0"},
      {:hackney, "~> 1.18"},
      {:jason, "~> 1.4"},
      {:nimble_csv, "~> 1.2"},
      {:progress_bar, "~> 2.0"},
      {:toml, "~> 0.7"},
      {:logger_file_backend, "~> 0.0.13"}
    ]
  end
end
