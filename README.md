# DynamicForm

A library for creating dynamic forms with full backend validation using
changesets and calls to backend functions in Elixir Phoenix. Also supports
building forms through a WYSIWYG interface.

This library enables users to build forms dynamically through a visual interface,
then render those forms using standard Phoenix LiveView patterns with robust
validation and backend integration.

## Defining Forms

Forms can be defined two ways, both rendered through the same
`DynamicForm.form/1` component:

- **Declaratively in the template** with `<:field>` slots — for forms owned by
  application code.
- **As data** in [SurveyJS-compatible JSON](https://surveyjs.io/form-library/documentation)
  — for forms that are stored, generated, or built in a WYSIWYG editor.

Both converge on the same `DynamicForm.Instance` struct internally, so
validation, conditional logic, and backend submission behave identically.

## Declarative Form Definitions

Define a form directly in HEEx with `<:field>` slots, in render order:

```heex
<DynamicForm.form id="contact-form" title="Contact Form" send_messages>
  <:field type="text" input_type="email" name="email" label="Email Address"
          required format="email" />
  <:field type="dropdown" name="subject" label="Subject"
          options={[{"Support", "support"}, {"Sales", "sales"}]} />
  <:field type="comment" name="details" label="Details"
          visible_if="{subject} = 'support'" />
</DynamicForm.form>
```

```elixir
# In the parent LiveView
def handle_info({:dynamic_form_success, _id, result}, socket) do
  {:noreply, put_flash(socket, :info, result[:message])}
end
```

Slot attrs are snake_case and map to the SurveyJS-style fields (`label` →
`title`, `options` → `choices`, `visible_if` → `visibleIf`, ...). Validation
attrs are flattened for the common cases — `min_length`, `max_length`, `min`,
`max`, `pattern`, `format="email"` — with `validators={[...]}` as the escape
hatch. Invalid definitions (duplicate names, choice fields without options,
unknown types, ...) raise with a descriptive message at render time.

See `DynamicForm.form/1` for the full attribute reference and
`DynamicForm.Instance.FromSlots` for the conversion rules.

### Groups (panels)

Fields sharing a `group` attribute are collected into a panel declared by a
`<:group>` entry. The panel renders at the position of its first member field:

```heex
<:field type="boolean" name="ship" label="Ship to a different address?" />

<:group name="address" title="Shipping Address" visible_if="{ship} = true" />
<:field group="address" type="text" name="street" label="Street" required />
<:field group="address" type="text" name="city" label="City" required />
```

### Custom markup

A `<:field>` slot body customizes rendering at three levels:

```heex
<%!-- 1. Content block: compile-checked HEEx instead of an html string,
     escaped by default, can read parent assigns --%>
<:field type="html" name="intro">
  <h2>Welcome, {@current_user.name}</h2>
</:field>

<%!-- 2. Custom control: the body receives the Phoenix.HTML.FormField and
     replaces the input; the library still renders the label and errors,
     and the changeset still validates the field --%>
<:field type="text" input_type="number" name="budget" label="Budget" min={0} :let={field}>
  <input type="range" min="0" max="1000" name={field.name} id={field.id}
         value={field.value || 0} />
</:field>

<%!-- 3. Fully custom element: the body receives the Phoenix form --%>
<:field type="custom" name="summary" :let={form}>
  <p>Total: {Phoenix.HTML.Form.input_value(form, :budget)}</p>
</:field>
```

Slot bodies are in-memory only: an instance containing them can be
JSON-encoded (the bodies are dropped), but declarative forms are owned by the
code that defines them and cannot round-trip through the WYSIWYG builder.

## SurveyJS-Compatible Data Format

Form definitions can also be [SurveyJS-compatible JSON](https://surveyjs.io/form-library/documentation).
Decode the JSON into an instance (e.g. in `mount/3` — not in a template; the
struct itself is not renderable):

```elixir
instance = DynamicForm.Instance.decode!(~S({
  "title": "Contact Form",
  "elements": [
    {
      "type": "text",
      "name": "email",
      "inputType": "email",
      "title": "Email Address",
      "isRequired": true,
      "validators": [{"type": "email"}]
    },
    {
      "type": "dropdown",
      "name": "subject",
      "title": "Subject",
      "choices": [{"value": "support", "text": "Support"}]
    },
    {
      "type": "comment",
      "name": "details",
      "title": "Details",
      "visibleIf": "{subject} = 'support'"
    }
  ]
}))
```

Then pass the instance to the same component:

```elixir
# In your LiveView
def mount(_params, _session, socket) do
  {:ok, assign(socket, :form_instance, instance)}
end

def handle_info({:dynamic_form_success, _id, result}, socket) do
  {:noreply, put_flash(socket, :info, result[:message])}
end
```

```heex
<DynamicForm.form id="contact-form" instance={@form_instance} send_messages />
```

`DynamicForm.form/1` requires exactly one of the `instance` attribute or
`<:field>` slots. Rendering the `DynamicForm.RendererLive` LiveComponent
directly with `<.live_component>` is equivalent and remains supported; for
custom state management, use the stateless `DynamicForm.Renderer.render/1`
function component instead.

### Supported question types

| Type | Renders as | Notes |
|------|-----------|-------|
| `text` | `<input>` | `inputType` passes through (`email`, `number`, ...) |
| `comment` | `<textarea>` | |
| `dropdown` | `<select>` | |
| `radiogroup` | Radio buttons | `metadata.style`: `vertical`/`horizontal` |
| `checkbox` | Checkbox group | Array-valued |
| `tagbox` | Multi-select | Array-valued |
| `boolean` | Single checkbox | |
| `rating` | Numeric radio row | `rateMin`/`rateMax`/`rateStep` (default 1–5) |
| `file` | Direct upload | Presigner configured via `metadata` |

Element types: `html`, `panel` (nesting container; declared via `<:group>` in
declarative mode), `image`, and `custom` (declarative mode only, requires a
slot body).

### Conditional logic

`visibleIf`, `requiredIf`, and `enableIf` (slot attrs: `visible_if`,
`required_if`, `enable_if`) accept SurveyJS expressions:

```
{field} = 'value'        {field} notempty         {field} > 100
{a} = 'x' and {b} empty  {tags} anyof ['a', 'b']  {list} contains 'item'
```

Supported operators: `=`, `==`, `<>`, `!=`, `>`, `<`, `>=`, `<=`, `empty`,
`notempty`, `contains`, `notcontains`, `anyof`, `allof`, `noneof`, combined
with `and`, `or`, and parentheses. Hidden required questions are excluded
from validation automatically.

### Validators

`text` (`minLength`/`maxLength`), `numeric` (`minValue`/`maxValue`), `email`,
and `regex`. Each accepts a custom error message via `text`. In declarative
mode the flattened attrs (`min_length`, `min`, `pattern`, `format`, ...)
build these validators automatically.

Not supported (rendered as a visible fallback box): matrix types,
`paneldynamic`, `multipletext`, `signaturepad`, `imagepicker`, `ranking`,
`slider`, `expression`. Multi-page definitions are flattened into a single
form.

## Installation

When using as a path dependency in your Phoenix app:

```elixir
def deps do
  [
    {:dynamic_form, path: "../"}
  ]
end
```

### Tailwind setup

The form components are styled with Tailwind and assume the
[@tailwindcss/forms](https://github.com/tailwindlabs/tailwindcss-forms)
plugin (it provides input border widths, appearance resets, and
checkbox/radio styling).

- **Phoenix ≤ 1.7 apps**: the generated `tailwind.config.js` already includes
  `@tailwindcss/forms` — only the content path for DynamicForm's classes
  needs adding:

  ```js
  content: [
    // ...
    "../deps/dynamic_form/lib/**/*.ex"
  ]
  ```

- **Phoenix 1.8+ apps** (CSS-based Tailwind v4 config): the plugin is *not*
  included by the generator — add both lines to `assets/css/app.css`. No npm
  install is needed; the Phoenix-managed standalone Tailwind CLI bundles the
  first-party plugins:

  ```css
  /* Include DynamicForm's classes in the Tailwind build */
  @source "../../deps/dynamic_form/lib";

  @plugin "@tailwindcss/forms";
  ```

## Example App

The `examples/demo/` directory contains a full Phoenix app exercising the
library, including a `/slot-forms` page demonstrating declarative
definitions, groups, and all three custom-markup tiers. The demo is
generated from a pinned `phx.new` skeleton plus the version-controlled
`examples/overlay/` — see `examples/README.md`.
