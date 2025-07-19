defmodule SickGrandma.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/your_username/sick_grandma"

  def project do
    [
      app: :sick_grandma,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "SickGrandma",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    A library for dumping ETS table data to log files. 
    Provides functionality to discover all running ETS tables and dump their contents 
    to structured log files in ~/.sick_grandma/logs/.
    """
  end

  defp package do
    [
      name: "sick_grandma",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "SickGrandma",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
