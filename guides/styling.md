# Styling

> How DynamicForm's markup gets its look, and every level of customizing it —
from swapping in your app's own components to taking over a single control.

DynamicForm owns the markup for everything it renders: inputs, labels,
errors, panels, and the submit button. Styling happens at four levels, from
broadest to narrowest:

1. **Default styling** — the built-in components, styled like a freshly
   generated Phoenix 1.8 app.
2. **A custom components module** — point the library at your app's
   `CoreComponents` (or design system) and every form renders through it.
3. **Per-field custom markup** — slot bodies take over a single control or
   block while the library keeps the rest.
4. **Render-only mode** — the escape hatch when your LiveView should own the
   whole form loop.

## Default styling

The built-in components (`DynamicForm.CoreComponents`) use the same markup
`phx.new` 1.8 generates: Tailwind utility classes plus
[daisyUI](https://daisyui.com) component classes (`input`, `select`,
`checkbox`, `radio`, `btn`, `fieldset`, ...).

Phoenix 1.8+ apps vendor daisyUI by default, so the only setup is pointing
Tailwind at DynamicForm's source in `assets/css/app.css`:

```css
@source "../../deps/dynamic_form/lib";
```

Apps without daisyUI (Phoenix ≤ 1.7, or apps that removed it) can either
vendor daisyUI the way `phx.new` 1.8 does — see the comments in a freshly
generated `assets/css/app.css` — or skip the built-in styling entirely with
a custom components module, below.

## Custom components module

The primary styling mechanism: point the library at your own components
module and forms render through it instead of the built-ins. Globally:

```elixir
config :dynamic_form, components: MyAppWeb.CoreComponents
```

or per form (the attribute wins over the config):

```heex
<DynamicForm.form id="contact-form" components={MyAppWeb.CoreComponents}>
```

A stock Phoenix-generated `CoreComponents` works out of the box — restyle
`core_components.ex` and every dynamic form follows your app.

### Per-function dispatch and fallback

Your module only needs to define the functions it wants to own. Each
component the renderer needs is looked up with `function_exported?/3` and
falls back to the built-in when missing:

| Function | Renders | In Phoenix-generated CoreComponents? |
|---|---|---|
| `input/1` | text/email/number, textarea, select, checkbox controls | yes — works out of the box |
| `input_radio_group/1` | radiogroup and rating questions | no — built-in fallback |
| `input_checkbox_group/1` | multi-select checkbox groups | no — built-in fallback |
| `label/1`, `error/1` | around custom-control slot bodies | no — built-in fallback |
| `dynamic_form_group/1` | groups (panels) | no — built-in fallback |
| `nested_entry/1` | the container around each repeating nested-form entry | no — built-in fallback |
| `button/1` | the submit button and a nested form's add button | yes — delegates |
| `translate_error/1` | error messages via the app's Gettext | yes — delegates |

Dispatch is deliberately per named function rather than "send everything to
`input/1`": a Phoenix-generated `input/1` ends in a catch-all clause, so an
unknown type like `"radio-group"` would silently render a broken
`<input type="radio-group">`. The named contract keeps every control either
correctly delegated or correctly built-in.

A module that can't be loaded raises — a typo fails loudly instead of
silently rendering built-in styling.

### Writing a partial module

Since fallback is per function, a components module can be a thin overlay.
This one restyles only the error messages and the submit button and leaves
every input to the built-ins:

```elixir
defmodule MyAppWeb.FormComponents do
  use Phoenix.Component

  def error(assigns) do
    ~H"""
    <p class="mt-1 text-xs font-medium text-red-700">{render_slot(@inner_block)}</p>
    """
  end

  def button(assigns) do
    ~H"""
    <button type={@type} disabled={@disabled} class="btn btn-secondary btn-wide" {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end
end
```

The assigns each function receives match the built-in implementations in
`DynamicForm.CoreComponents` — `input/1` gets `field`, `type`, `label`, and
per-type extras (`options`, `prompt`, `multiple`, `rows`, `placeholder`,
`disabled`); the radio and checkbox group components get `field`, `label`,
`options`, `style`, `disabled`; `dynamic_form_group/1` gets `type`, `title`,
`name`, `disabled`, and an `inner_block` slot; `button/1` gets `type`,
`disabled`, `rest`, and an `inner_block` slot. See `DynamicForm.Components`
for the full contract.

`button/1` renders both the submit button and a nested form's add button, and
the add button's `phx-click` arrives in `rest` — so splat it
(`<button {@rest}>`), as a Phoenix-generated button does. A button that drops
globals looks right and does nothing when clicked.

### The required mark

`label` is plain text. A required field's mark arrives separately, as
`required` and `required_label`, so your component decides where and how it
renders:

```elixir
def input(assigns) do
  ~H"""
  <label>
    {@label}<span :if={@required && @required_label} class="text-error">{@required_label}</span>
    <input type={@type} name={@field.name} value={@field.value} required={@required} />
  </label>
  """
end
```

`required_label` is already resolved: a string to render, or `nil`/`false` when
the definition suppresses it. `required` is `true` whenever the field is
required, whether or not a mark shows — so pass it to the control if you want
the browser to enforce it. `input/1`, `input_radio_group/1`,
`input_checkbox_group/1`, and `label/1` all receive both.

The built-ins render `<span class="ml-0.5 text-red-500">` after the label text,
and put the HTML `required` attribute on text, textarea, select, radio, and
single-checkbox controls — but not on a checkbox *group*, where it would demand
every option rather than one.

### Custom group types

`dynamic_form_group/1` wraps each `<:group>`, and it dispatches on `type` the
same way `input/1` dispatches on its own — so a layout the library doesn't
ship is a clause in your module plus the name in the definition:

```heex
<:group name="plans" title="Plans" type="cards" />
```

```elixir
def dynamic_form_group(%{type: "cards"} = assigns) do
  ~H"""
  <section class="grid grid-cols-3 gap-6">
    <h3 class="col-span-3 text-lg font-medium">{@title}</h3>
    {render_slot(@inner_block)}
  </section>
  """
end

def dynamic_form_group(assigns), do: DynamicForm.CoreComponents.dynamic_form_group(assigns)
```

That last clause matters. Fallback is per *function*, not per type, so once
your module exports `dynamic_form_group/1` it owns every group in every form —
including the built-in `"horizontal"` and `"vertical"`. Delegating in a
catch-all keeps them working; omitting it raises `FunctionClauseError` the
first time a group doesn't name your type.

`name` is there so one clause can treat two groups differently without
inventing a type per group, and `disabled` reflects the group's effective
state — its own `enable_if`, or inherited from a disabled form or an
enclosing group.

## Per-field custom markup

For one special field rather than a whole design system, give the `<:field>`
a slot body. Three tiers, all declarative-mode only:

**Custom controls** — the body receives the `Phoenix.HTML.FormField` and
replaces just the input, while the library still renders the label and
errors, and the changeset still validates the field:

```heex
<:field :let={field} type="text" name="budget" input_type="number" label="Budget">
  <input type="range" min="0" max="1000" step="50"
         name={field.name} id={field.id} value={field.value || 0}
         class="range range-primary" />
</:field>
```

Whatever the control submits under `field.name` flows through validation
unchanged. This also composes with your own component library — call it at
the control level (pass `name`/`id`/`value`, not `field`) so it renders just
the styled input and the library keeps ownership of the label and errors:

```heex
<:field :let={field} type="dropdown" name="occupation" label="Occupation" options={@occupations}>
  <MyAppWeb.DesignSystem.input
    type="select"
    name={field.name}
    id={field.id}
    value={field.value}
    options={@occupations}
  />
</:field>
```

**Content blocks** — arbitrary HTML positioned within the form, escaped
HEEx that can read parent assigns:

```heex
<:field type="html" name="intro">
  <div class="alert alert-info">Welcome back, {@current_user.name}</div>
</:field>
```

**Fully custom elements** — the body receives the Phoenix form for markup
that reads current values (display-only; not a validated field):

```heex
<:field :let={form} type="custom" name="summary">
  <p class="text-sm">Total: {Phoenix.HTML.Form.input_value(form, :budget)}</p>
</:field>
```

See [Usage: Custom markup](usage.md#custom-markup-slot-bodies) for the full
slot-body contract.

## Full control: render-only mode

When styling hooks aren't enough and your LiveView should own the whole
loop, `render_only` renders the definition against a parent-owned form and
sends the `phx-change`/`phx-submit` events to the parent — see
[Usage: Render-only mode](usage.md#render-only-mode). The markup still comes
from the components module (custom or built-in); what changes is who owns
the state.
