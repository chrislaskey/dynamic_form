defmodule DynamicForm.MixProject do
  use Mix.Project

  @version "0.23.9"
  @source_url "https://github.com/chrislaskey/dynamic_form"

  def project do
    [
      app: :dynamic_form,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "DynamicForm",
      description: description(),
      package: package(),
      docs: docs(),
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
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_ecto, ">= 0.0.0"},
      {:ecto, ">= 0.0.0"},
      {:gettext, ">= 0.0.0"},
      {:jason, ">= 0.0.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Dynamic forms for Phoenix LiveView with built-in validation - " <>
      "defined declaratively in HEEx or as (SurveyJS-compatible) data"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib guides mix.exs README.md CHANGELOG.md LICENSE.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "LICENSE.md",
        "guides/usage.md",
        "guides/nested-forms.md",
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
