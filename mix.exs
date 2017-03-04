defmodule Janus.Mixfile do
  use Mix.Project

  def project do
    [
      app: :janus,
      version: "0.1.0",
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "Janus",
      source_url: "https://github.com/ndarilek/elixir-janus",
      homepage_url: "https://github.com/ndarilek/elixir-janus",
      docs: [
        main: "Janus",
        extras: ["README.md"]
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger, :httpoison],
     mod: {Janus.Application, []}]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:httpoison, "~> 0.10"},
      {:poison, "~> 3.1"},
      {:ex_doc, "~> 0.14", only: :dev},
      {:uuid, "~> 1.1"},
      {:bypass, "~> 0.1", only: :test}
    ]
  end

end
