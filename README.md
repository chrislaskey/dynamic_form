# DynamicForm

> Dynamic, changeset-backed forms for Phoenix LiveView — defined declaratively
> in HEEx or as (SurveyJS-compatible) data.

## Architecture

DynamicForm renders complete, validated forms from a single definition. A
definition can be written two ways, and both converge on the same
`DynamicForm.Instance` struct — so validation, conditional logic, and
submission behave identically:

- **Data** — [SurveyJS-compatible JSON](https://surveyjs.io/form-library/documentation)
  (or maps/structs), for forms that are stored in a database, generated at
  runtime, or built in a WYSIWYG editor.
- **Declarative** — `<:field>` slots inside `<DynamicForm.form>`, for forms
  owned by application code and co-located with the template.

In declarative mode, everything is composed from slots:

- **`<:field>`** — every question and element in render order: text, comment,
  dropdown, radiogroup, checkbox, boolean, rating, tagbox, file uploads, plus
  html/image content blocks.
- **`<:group>`** — collects fields into a titled panel, with its own
  conditional visibility.
- **Slot bodies** — custom markup at three tiers: content blocks, custom
  controls that receive the form field (the library keeps the label, errors,
  and validation), and fully custom elements that receive the form.

Whichever mode defines the form, the library owns the full lifecycle: an Ecto
changeset built from the definition (types, required fields, validators),
SurveyJS conditional expressions (`visible_if`, `required_if`, `enable_if`)
evaluated live as the user types, direct-to-cloud file uploads, and
submission through a small backend behaviour your application implements.

## Examples

A form is a component call with fields in render order:

```heex
<DynamicForm.form id="contact-form" send_messages>
  <:field type="text" name="name" label="Name" required />
  <:field type="text" name="email" input_type="email" label="Email Address" required format="email" />
</DynamicForm.form>
```

```elixir
def handle_info({:dynamic_form_success, _id, result}, socket) do
  {:noreply, put_flash(socket, :info, result.message)}
end
```

Layer in validation attrs and conditional visibility — the details field only
appears when the subject is `support`, and hidden required fields are
excluded from validation automatically:

```heex
<DynamicForm.form id="support-form" send_messages>
  <:field type="text" name="name" label="Name" required min_length={2} />
  <:field type="dropdown" name="subject" label="Subject" required options={[{"Support", "support"}, {"Sales", "sales"}]} />
  <:field type="comment" name="details" label="Support Details" visible_if="{subject} = 'support'" />
  <:field type="rating" name="satisfaction" label="Satisfaction" rate_min={1} rate_max={5} />
</DynamicForm.form>
```

Group fields into panels, and take over rendering where you need to — here a
custom range control via a slot body, while the library still owns the label,
errors, and changeset validation:

```heex
<DynamicForm.form id="checkout-form" send_messages>
  <:field type="boolean" name="ship" label="Ship to a different address?" />

  <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
  <:field group="address" type="text" name="street" label="Street" required />
  <:field group="address" type="text" name="city" label="City" required />

  <:field :let={field} type="text" name="budget" input_type="number" label="Budget">
    <input type="range" min="0" max="1000" step="50" name={field.name} id={field.id} value={field.value || 0} />
  </:field>
</DynamicForm.form>
```

Or define the same form as data. SurveyJS-compatible JSON passes straight in
via the `json` attribute (`<DynamicForm.form id="contact-form" json={@json} />`),
or decode it at the edge — from JSON, a map, or built as structs — and pass
the instance to the same component:

```json
{
  "title": "Contact Form",
  "elements": [
    {"type": "text", "name": "name", "inputType": "text"},
    {"type": "text", "name": "email", "inputType": "email"}
  ]
}
```

```heex
<DynamicForm.form id="contact-form" json={@json} send_messages />
```

Every example runs live in the demo app — the
[Slot Forms page](examples/overlay/lib/demo_web/live/slot_form_live.ex) shows
each definition alongside its rendered form. Every feature is explained in
depth in the [Usage guide](guides/usage.md).

## Demo app

The `/examples` directory contains a full Phoenix demo app exercising every
feature — declarative and data definitions, every question type, conditional
logic, panels, custom markup, file uploads, and backend submission:

```
git clone https://github.com/chrislaskey/dynamic_form.git
cd dynamic_form/examples/demo
mix setup && iex -S mix phx.server
```

The demo is generated: `examples/regenerate.sh` rebuilds it from a pinned
`phx.new` release, then applies the version-controlled `examples/overlay/`
directory on top. The interesting demo code — LiveViews, form definitions,
layout tweaks — lives in the overlay; edit there, copy over the demo
(`cp -R overlay/. demo/`), and never edit generated files directly.

## Additional documentation

- **[Usage](guides/usage.md)** — every feature in depth: both definition
  modes, question types, validation, conditional logic, groups, custom
  markup, rendering options, edit mode, backends, and file uploads
- **[SurveyJS compatibility](guides/surveyjs.md)** — defining forms as data:
  what's supported, what isn't, and DynamicForm's extensions
- **[Reference](guides/reference.md)** — quick tables for every attribute,
  slot, question type, validator, and expression operator
- **[Development](guides/development.md)** — the demo app workflow,
  architecture notes, and testing

## Installation

DynamicForm is not yet published to Hex. Add it as a path or git dependency
in `mix.exs`:

```elixir
def deps do
  [
    {:dynamic_form, path: "../dynamic_form"}
    # or: {:dynamic_form, git: "https://github.com/chrislaskey/dynamic_form.git"}
  ]
end
```

### Tailwind CSS

The components are styled with Tailwind utility classes and assume the
[@tailwindcss/forms](https://github.com/tailwindlabs/tailwindcss-forms)
plugin (input border widths, appearance resets, checkbox/radio styling).

Tailwind v4 (`assets/css/app.css`) — Phoenix 1.8+ generators do **not**
include the forms plugin, so add both lines (no npm install needed; the
Phoenix-managed standalone Tailwind CLI bundles the first-party plugins):

```css
@source "../../deps/dynamic_form/lib";
@plugin "@tailwindcss/forms";
```

Tailwind v3 (`assets/tailwind.config.js`) — Phoenix ≤ 1.7 generators already
include the forms plugin, so only the source path is needed:

```js
content: [
  // ...existing paths
  "../deps/dynamic_form/lib/**/*.ex",
],
```

### File uploads (optional)

Direct-to-cloud file uploads (`type="file"`) require a presigner module and
a JavaScript uploader registered in `assets/js/app.js` — see
[Usage: File uploads](guides/usage.md#file-uploads).

## License

MIT — see [LICENSE.md](LICENSE.md).
