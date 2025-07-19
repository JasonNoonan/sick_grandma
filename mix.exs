defmodule SickGrandma.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jasonnoonan/sick_grandma"

  def project do
    [
      app: :sick_grandma,
      version: @version,
      elixir: "~> 1.17",
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
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* usage-rules.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "SickGrandma",
      name: "SickGrandma",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: [
        "README.md",
        "guides/getting-started.md",
        "guides/advanced-usage.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.?/
      ],
      groups_for_modules: [
        Core: [SickGrandma],
        Internal: [SickGrandma.ETSDumper, SickGrandma.Logger]
      ],
      groups_for_docs: [
        "Main API": &(&1[:section] == :main_api),
        "Table Operations": &(&1[:section] == :table_ops),
        Utilities: &(&1[:section] == :utilities)
      ],
      before_closing_head_tag: &docs_before_closing_head_tag/1,
      before_closing_body_tag: &docs_before_closing_body_tag/1,
      api_reference: true,
      formatters: ["html"],
      filter_modules: fn _module, _ ->
        # Include all modules for now
        true
      end,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp docs_before_closing_head_tag(:html) do
    """
    <style>
      .content-inner { max-width: 1000px; }
      .sidebar .sidebar-listNav { font-size: 14px; }
    </style>
    """
  end

  defp docs_before_closing_head_tag(_), do: ""

  defp docs_before_closing_body_tag(:html) do
    """
    <script>
      // Add any custom JavaScript for docs here
    </script>
    """
  end

  defp docs_before_closing_body_tag(_), do: ""
end
