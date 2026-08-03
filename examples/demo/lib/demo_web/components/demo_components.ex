defmodule DemoWeb.DemoComponents do
  @moduledoc """
  Shared components for the demo pages.

  Every demo page shows the form definition (template markup, structs, or
  JSON) above the rendered form, so viewers can read what the form contains
  before seeing the result.
  """

  use Phoenix.Component

  @doc """
  Renders a form definition code block, shown above the rendered form.

  ## Examples

      <.definition title="Form Definition (JSON)" code={@json_pretty} />
  """
  attr :title, :string, default: "Form Definition"
  attr :subtitle, :string, default: nil
  attr :code, :string, required: true

  def definition(assigns) do
    ~H"""
    <div class="mb-6 rounded-lg bg-gray-50 border border-gray-200 p-4">
      <h3 class="text-sm font-semibold text-gray-900">{@title}</h3>
      <p :if={@subtitle} class="mt-1 text-xs text-gray-600">{@subtitle}</p>
      <pre class="mt-3 p-4 rounded-lg bg-white border border-gray-200 text-xs text-zinc-700 overflow-auto max-h-96"><code>{String.trim_trailing(@code)}</code></pre>
    </div>
    """
  end
end
