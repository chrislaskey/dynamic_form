defmodule DynamicForm.Components do
  @moduledoc """
  Resolution and dispatch for the pluggable components module.

  DynamicForm renders inputs, labels, and errors through
  `DynamicForm.CoreComponents` by default. Applications can point the library
  at their own components module — typically the Phoenix-generated
  `MyAppWeb.CoreComponents` — either globally:

      config :dynamic_form, components: MyAppWeb.CoreComponents

  or per form:

      <DynamicForm.form id="contact-form" components={MyAppWeb.CoreComponents}>

  The per-form attribute wins over the config; without either, the built-in
  module renders everything.

  ## The contract, and per-function fallback

  Dispatch is per function: each component the renderer needs is looked up on
  the configured module with `function_exported?/3`, falling back to the
  built-in implementation when the module doesn't define it. A module only
  needs to define the functions it wants to own:

  | Function | Renders | Phoenix-generated CoreComponents? |
  |---|---|---|
  | `input/1` | text, email, number, textarea, select, checkbox controls (receives `field`, `type`, `label`, and per-type extras like `options`/`prompt`/`multiple`) | yes — works out of the box |
  | `input_radio_group/1` | radiogroup and rating questions | no — built-in fallback |
  | `input_checkbox_group/1` | multi-select checkbox groups | no — built-in fallback |
  | `label/1`, `error/1` | around custom-control slot bodies | no (private in Phoenix 1.8) — built-in fallback |
  | `dynamic_form_group/1` | groups (panels); dispatches on `type` like `input/1` (receives `type`, `title`, `name`, `disabled`, `inner_block`) | no — built-in fallback |
  | `nested_entry/1` | the container around each repeating nested-form entry (receives `index`, `name`, and the entry contents as `inner_block`) | no — built-in fallback |
  | `button/1` | the submit button and a nested form's add button (receives `type`, `disabled`, `rest`, `inner_block`) | yes — delegates when exported |
  | `translate_error/1` | error messages (routes through the app's Gettext) | yes — delegates when exported |

  A `button/1` must splat its global attributes — `<button {@rest}>` — the way
  a Phoenix-generated one does. The nested-form add button carries its
  `phx-click` in `rest`, so a button that drops globals renders fine and does
  nothing when clicked.

  Delegation is intentionally NOT a blanket "send everything to `input/1`":
  a Phoenix-generated `input/1` ends in a catch-all clause, so an unknown
  type like `"radio-group"` would render a broken `<input type="radio-group">`
  instead of raising. The named-function contract keeps every control either
  correctly delegated or correctly built-in.
  """

  alias DynamicForm.CoreComponents

  @doc """
  Resolves the components module: the per-form value when given, otherwise
  the `:components` application config, otherwise `nil` (built-in only).

  Raises `ArgumentError` when the module cannot be loaded, so a typo fails
  loudly instead of silently falling back to the built-in components.
  """
  def resolve(nil) do
    case Application.get_env(:dynamic_form, :components) do
      nil -> nil
      module -> ensure_loaded!(module)
    end
  end

  def resolve(module) when is_atom(module), do: ensure_loaded!(module)

  @doc """
  Whether the components module provides its own `fun/1` implementation.
  """
  def provides?(nil, _fun), do: false
  def provides?(module, fun) when is_atom(module), do: function_exported?(module, fun, 1)

  @doc """
  Renders the component `fun` with `assigns`, delegating to the components
  module when it exports the function and falling back to
  `DynamicForm.CoreComponents` otherwise.
  """
  def render(components, fun, assigns) when is_map(assigns) do
    module = if provides?(components, fun), do: components, else: CoreComponents

    Phoenix.LiveView.TagEngine.component(
      Function.capture(module, fun, 1),
      assigns,
      {module, {fun, 1}, __ENV__.file, __ENV__.line}
    )
  end

  @doc """
  Translates an error tuple, delegating to the components module's
  `translate_error/1` when exported — routing messages through the
  application's own Gettext — and falling back to the built-in translation
  with the given Gettext backend otherwise.
  """
  def translate_error(components, error, gettext_backend \\ DynamicForm.Gettext)

  def translate_error(components, {_msg, _opts} = error, gettext_backend) do
    if provides?(components, :translate_error) do
      components.translate_error(error)
    else
      CoreComponents.translate_error(error, gettext_backend)
    end
  end

  defp ensure_loaded!(module) do
    if Code.ensure_loaded?(module) do
      module
    else
      raise ArgumentError,
            "DynamicForm components module #{inspect(module)} could not be loaded — " <>
              "check the components attribute or the :dynamic_form, :components config"
    end
  end
end
