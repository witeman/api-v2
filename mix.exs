defmodule CanvasAPI.Mixfile do
  use Mix.Project

  @github_url "https://github.com/usecanvas/pro-api"
  @version "0.0.1"

  def project do
    [app: :canvas_api,
     description: "The Canvas API",
     version: @version,
     name: "Canvas API",
     homepage_url: @github_url,
     source_url: @github_url,
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {CanvasAPI, []},
     applications: applications(Mix.env)]
  end

  defp applications(:prod) do
    applications ++ [:appsignal, :sentry]
  end

  defp applications(_), do: applications

  defp applications do
    [:phoenix, :cowboy, :logger, :gettext, :phoenix_ecto, :postgrex, :calecto,
     :slack, :base62, :httpoison, :timex, :floki, :logfmt,
     :phoenix_pubsub_redis]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.2.1"},
     {:phoenix_pubsub, "~> 1.0"},
     {:phoenix_ecto, "~> 3.0"},
     {:postgrex, ">= 0.0.0"},
     {:gettext, "~> 0.11"},
     {:cowboy, "~> 1.0"},
     {:calecto, "~> 0.16.0"},
     {:slack_ex, "~> 0.0.14", app: false},
     {:base62, "~> 1.2.0"},
     {:httpoison, "~> 0.9.1"},
     {:timex, "~> 3.0"},
     {:floki, "~> 0.10.1"},
     {:base62_uuid, "~> 1.2.3"},
     {:appsignal, "~> 0.11"},
     {:exq, github: "akira/exq", ref: "84e05ff"},
     {:ecto, github: "elixir-ecto/ecto", ref: "8460f42", override: true},
     {:sentry, "~> 2.0"},
     {:logfmt, "~> 3.2.0"},
     {:phoenix_pubsub_redis, "~> 2.1"},
     {:credo, "~> 0.4", only: [:dev, :test]},
     {:ex_doc, "~> 0.14", only: [:dev]},
     {:mix_test_watch, "~> 0.2", only: [:dev]},
     {:ex_machina, "~> 1.0", only: [:test]},
     {:mock, "~> 0.2.0", only: [:test]},
     {:ex_unit_notifier, "~> 0.1", only: [:test]}]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "docs": ["docs --output=docs"],
     "test": ["ecto.migrate", "test"]]
  end
end
