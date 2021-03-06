defmodule Dufa.Mixfile do
  use Mix.Project

  @description """
  Library for sending push notifications via GCM and APN services.
  """

  def project do
    [app: :dufa,
     version: "0.2.2",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     name: "Dufa",
     description: @description,
     package: package(),
     deps: deps(),
     source_url: "https://github.com/madeinussr/dufa",
     docs: [extras: ["README.md"]]]
  end

  def application do
    [applications: [:logger, :httpoison],
     mod: {Dufa, []}]
  end

  defp deps do
    [
      {:poison, "~> 3.0"},
      {:httpoison, "~> 0.10.0"},
      {:mock, "~> 0.1.1", only: :test},
      {:chatterbox, github: "joedevivo/chatterbox"}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      maintainers: ["Andrey Chernykh"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/madeinussr/dufa"}
    ]
  end
end
