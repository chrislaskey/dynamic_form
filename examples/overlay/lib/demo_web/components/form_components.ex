defmodule DemoWeb.FormComponents do
  @moduledoc """
  A components module extending the app's CoreComponents with a custom
  field type.

  Demonstrates the custom field type pattern: the `"multiselect"` type is
  registered via `custom_field_types` (declaring it casts as
  `{:array, :string}`) and rendered by the matching `input/1` clause here.
  Every other input delegates to the app's Phoenix-generated CoreComponents.
  """

  use Phoenix.Component

  # The custom "multiselect" field type: checkbox pills submitting a list
  # under name[]. The hidden "" entry keeps the field present when nothing
  # is selected, and the library's array normalization (driven by the
  # registered {:array, :string} type) makes `required` work.
  def input(%{type: "multiselect", field: %Phoenix.HTML.FormField{} = field} = assigns) do
    selected = field.value |> List.wrap() |> Enum.map(&to_string/1)
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns =
      assigns
      |> assign(:selected, selected)
      |> assign(:errors, Enum.map(errors, &DemoWeb.CoreComponents.translate_error/1))

    ~H"""
    <fieldset class="fieldset mb-2">
      <span :if={@label} class="label mb-1">{@label}</span>
      <input type="hidden" name={"#{@field.name}[]"} value="" />
      <div class="flex flex-wrap gap-2">
        <label
          :for={{text, value} <- @options}
          class="btn btn-sm has-[:checked]:btn-primary"
        >
          <input
            type="checkbox"
            name={"#{@field.name}[]"}
            value={value}
            checked={to_string(value) in @selected}
            class="hidden"
            disabled={@disabled}
          />
          {text}
        </label>
      </div>
      <p :for={msg <- @errors} class="mt-1.5 text-sm text-error">{msg}</p>
    </fieldset>
    """
  end

  # Everything else renders through the app's generated CoreComponents
  def input(assigns), do: DemoWeb.CoreComponents.input(assigns)
end
