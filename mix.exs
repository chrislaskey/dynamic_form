defmodule DynamicForm.MixProject do
  use Mix.Project

  @version "0.13.1"

  def project do
    [
      app: :dynamic_form,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto, "~> 3.0"},
      {:gettext, ">= 0.0.0"},
      {:jason, "~> 1.4"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "LICENSE.md",
        "guides/usage.md",
        "guides/surveyjs.md",
        "guides/lifecycle.md",
        "guides/styling.md",
        "guides/reference.md",
        "guides/development.md"
      ],
      groups_for_extras: [
        Guides: ~r{guides/}
      ]
    ]
  end
end
