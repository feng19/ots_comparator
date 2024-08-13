defmodule OtsComparator.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/feng19/ots_comparator"

  def project do
    [
      app: :ots_comparator,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aliyun_ots, "~> 0.15"},
      {:ex_doc, ">= 0.0.0", only: [:docs, :dev], runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "master",
      formatters: ["html"],
      formatter_opts: [gfm: true]
    ]
  end

  defp package do
    [
      name: "ots_comparator",
      description: "Comparator for OTS(Aliyun Tablestore Database)",
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["feng19"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
