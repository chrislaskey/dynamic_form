# Usage

Every feature in depth. For quick lookup tables see the
[Reference](reference.md); for the demo app and architecture notes see
[Development](development.md).

## Defining forms

A form definition can be written declaratively in the template or as data.
Both converge on the same `DynamicForm.Instance` struct, so everything below
the definition — validation, conditional logic, rendering, submission —
behaves identically.

### Declarative mode

Define fields with `<:field>` slots inside `DynamicForm.form/1`, in render
order:

```heex
<DynamicForm.form id="contact-form" title="Contact Form">
  <:field type="text" name="name" label="Name" required />
  <:field type="text" name="email" input_type="email" label="Email Address"
          required format="email" />
  <:field type="dropdown" name="subject" label="Subject"
          options={[{"Support", "support"}, {"Sales", "sales"}]} />
  <:field type="comment" name="details" label="Details" />
</DynamicForm.form>
```

Slot attrs are snake_case and map onto the SurveyJS-style `Instance` fields
(`label` → `title`, `options` → `choices`, `visible_if` → `visibleIf`, ...).
See the [Reference](reference.md) for every attribute.

Question types collect input: `text` (with `input_type` pass-through for
`email`, `number`, ...), `comment`, `dropdown`, `radiogroup`, `checkbox`,
`boolean`, `rating`, `tagbox`, and `file`. Element types render content:
`html`, `image`, and `custom` (declarative-only, requires a slot body).

Invalid definitions — missing or duplicate names, choice fields without
options, unknown types, fields referencing undeclared groups — raise
`ArgumentError` with a descriptive message at render time.

### Validation

Required fields use `required` (or `required_if` with an expression). The
common validators are flattened into attrs:

```heex
<:field type="text" name="username" label="Username" required
        min_length={3} max_length={20} />
<:field type="text" name="age" input_type="number" label="Age" min={18} max={130} />
<:field type="text" name="slug" label="Slug" pattern="^[a-z-]+$" />
<:field type="text" name="email" label="Email" format="email" />
```

For anything the flattened attrs can't express, pass
`DynamicForm.Instance.Validator` structs (or atom-keyed maps) directly —
including custom error messages via `:text`:

```heex
<:field type="text" name="code" label="Code"
        validators={[%DynamicForm.Instance.Validator{type: "regex", regex: "^[A-Z]+$",
                                                     text: "Uppercase letters only"}]} />
```

All validation runs server-side through an Ecto changeset built from the
definition. Inline field errors display once the changeset has an action —
set on submit — and stay live during subsequent edits.

### Conditional logic

`visible_if`, `required_if`, and `enable_if` accept SurveyJS expressions,
evaluated live against the current form values:

```
{field} = 'value'        {field} notempty         {field} > 100
{a} = 'x' and {b} empty  {tags} anyof ['a', 'b']  {list} contains 'item'
```

Supported operators: `=`, `==`, `<>`, `!=`, `>`, `<`, `>=`, `<=`, `empty`,
`notempty`, `contains`, `notcontains`, `anyof`, `allof`, `noneof`, combined
with `and`, `or`, and parentheses.

Hidden required questions are excluded from validation automatically, and a
disabled panel (`enable_if` false) disables every question inside it.

### Groups (panels)

Fields sharing a `group` attribute collect into a panel declared by a
`<:group>` entry. The panel renders at the position of its first member
field, so declaration order of the `<:group>` itself doesn't matter:

```heex
<:field type="boolean" name="ship" label="Ship to a different address?" />

<:group name="address" title="Shipping Address" visible_if="{ship} = true" />
<:field group="address" type="text" name="street" label="Street" required />
<:field group="address" type="text" name="city" label="City" required />
```

Groups support `visible_if`/`enable_if` like fields. Nested panels
(panel-in-panel) are currently a data-mode-only feature.

### Custom markup (slot bodies)

A `<:field>` body customizes rendering at three tiers.

**Content blocks** — an html body instead of the `html` string attr. The body
is compile-checked HEEx, escaped by default, and can read parent assigns:

```heex
<:field type="html" name="intro">
  <h2>Welcome, {@current_user.name}</h2>
</:field>
```

**Custom controls** — the body receives the `Phoenix.HTML.FormField` and
replaces the input, while the library still renders the label, description,
and errors, and the changeset still validates the field:

```heex
<:field :let={field} type="text" name="budget" input_type="number" label="Budget" min={0}>
  <input type="range" min="0" max="1000" step="50"
         name={field.name} id={field.id} value={field.value || 0} />
</:field>
```

Whatever the control submits under `field.name` flows through validation
unchanged — the same contract as `<.form :let={f}>`.

**Fully custom elements** — the body receives the Phoenix form, for arbitrary
markup positioned within the form that reads current values:

```heex
<:field :let={form} type="custom" name="summary">
  <p>Total: {Phoenix.HTML.Form.input_value(form, :budget)}</p>
</:field>
```

Slot bodies are in-memory only: instances containing them JSON-encode with
the bodies dropped, and declarative forms cannot round-trip through the
WYSIWYG builder.

### Data mode

Definitions can be SurveyJS-compatible JSON, maps, or `Instance` structs.
A JSON string passes straight in via the `json` attribute:

```heex
<DynamicForm.form id="contact-form" json={@json} />
```

Or decode at the edge (e.g. in `mount/3`) to work with the definition
programmatically, and pass the instance to the same component:

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
      "type": "comment",
      "name": "details",
      "title": "Details",
      "visibleIf": "{subject} = 'support'"
    }
  ]
}))
```

```heex
<DynamicForm.form id="contact-form" instance={@form_instance} />
```

Instances encode back to JSON with `Jason.encode!/1`, so definitions can be
stored in a database, served over an API, or cached.

See the [SurveyJS compatibility guide](surveyjs.md) for exactly which
SurveyJS features are supported, which are not (unsupported types render as
a visible fallback box), and DynamicForm's extensions to the format.

### Nested forms

A nested form is a repeating child form — a list of sub-records the user
adds and removes, like a contact with multiple addresses. The submitted
value is a nested list of maps, and every entry is validated with its own
changeset:

```elixir
%{name: "Ada", addresses: [%{street: "110 Main St", city: "Portland"}, ...]}
```

Nested forms work in both modes — the SurveyJS `paneldynamic` question type
in data mode, and `<:nested>` slot declarations in declarative mode:

```heex
<:nested name="addresses" title="Addresses" min_entries={1} add_text="Add another address" />
<:field nested="addresses" type="text" name="street" label="Street" required />
<:field nested="addresses" type="text" name="city" label="City" required />
```

See the [Nested Forms guide](nested-forms.md) for the full feature: the
scope model (`nested` + `group` combine), per-scope naming, entry
seeding, per-entry validation and key uniqueness, custom controls per
entry, and standalone-renderer events.

## Rendering

### `DynamicForm.form/1`

The unified entry point. Requires exactly one of the `instance` attribute
(data mode) or `<:field>` slots (declarative mode). Common options:

```heex
<DynamicForm.form
  id="profile-form"
  instance={@form_instance}
  data={%{"name" => "Jane"}}
  form_name="profile"
  submit_text="Save Profile"
  validation_summary="detailed"
/>
```

Internally it wraps `DynamicForm.RendererLive`, a LiveComponent that manages
the changeset, validation on change, and submission. Using the LiveComponent
directly with `<.live_component>` is equivalent.

### Edit mode

Pre-populate a form by passing `data`. Fields marked `read_only`
(`readOnly` in data mode) display their values but can't be edited — and
because browsers don't submit read-only/disabled inputs, the initial data
are merged back into every submission so those values survive validation:

```heex
<DynamicForm.form
  id="user-profile"
  instance={@form_instance}
  data={%{"id" => .id, "name" => .name, "email" => .email}}
/>
```

Extra keys in `data` that have no matching question (like `id` above) are
preserved through submission the same way.

### Messages

By default, the component sends the parent LiveView a
`{:dynamic_form, %DynamicForm.Payload{}}` message on every **valid**
submission — this is where the application performs the side effect (insert
a record, send an email, navigate). Invalid submissions render their errors
inline on the form and never message the parent:

```elixir
def handle_info({:dynamic_form, %DynamicForm.Payload{data: data}}, socket) do
  {:ok, contact} = MyApp.Contacts.create_contact(data)
  {:noreply, put_flash(socket, :info, "Created contact #{contact.id}")}
end
```

The payload carries the form's `id` (for matching when a page renders
several forms), the final `changeset`, the applied `data`, and an `extra`
map that `on_submit` can write derived values into.

To take over success handling, define `on_success` — a 1-arity function
receiving the payload. It **replaces** the default message: send a custom
message, broadcast over PubSub, or do nothing to make the form fully
self-contained:

```heex
<DynamicForm.form
  id="contact-form"
  instance={@form_instance}
  on_success={fn payload -> Phoenix.PubSub.broadcast(MyApp.PubSub, "contacts", payload.data) end}
/>
```

See the [Lifecycle events guide](lifecycle.md) for the full lifecycle and
payload.

### External submit buttons

Place the submit button anywhere on the page — modal footers, sticky bars —
by hiding the built-in button and using the HTML `form` attribute. The form
element's ID is `"#{component_id}-form"`:

```heex
<DynamicForm.submit_button form="profile-form-form">
  Save Profile
</DynamicForm.submit_button>

<DynamicForm.form id="profile-form" instance={@form_instance} hide_submit />
```

### Validation summary

Display errors at the top of the form in addition to inline errors:
`validation_summary="simple"` shows a generic message,
`validation_summary="detailed"` adds a list of each field error.

### Render-only mode

For full control over the form lifecycle, add `render_only` and pass the
parent-owned form: the component renders the definition's markup and emits
`phx-change`/`phx-submit` with no `phx-target`, so events land in the parent
LiveView's `handle_event/3` — exactly like an idiomatic
`<form phx-change="validate" phx-submit="submit">`. The definition drives
presentation (inputs, labels, errors, conditional visibility); the parent's
changeset drives the data:

```heex
<DynamicForm.form id="signup" render_only form={@form}>
  <:field type="text" name="name" label="Name" required />
  <:field type="text" name="email" input_type="email" label="Email" required />
</DynamicForm.form>
```

```elixir
def handle_event("validate", %{"signup" => params}, socket) do
  changeset = Accounts.change_user(%User{}, params) |> Map.put(:action, :validate)
  {:noreply, assign(socket, form: to_form(changeset, as: "signup"))}
end

def handle_event("submit", %{"signup" => params}, socket) do
  # entirely yours
end
```

Override the event names with `phx_change` and `phx_submit`. The lifecycle
attributes (`on_change`, `on_submit`, `on_success`, `data`, `form_name`,
`validation_summary`) have no meaning without the managed lifecycle and
raise, and file upload questions require the stateful component.

The Render Only section of the `/slot-forms` demo page shows the complete
pattern. `DynamicForm.Renderer.render/1` is the underlying function
component if you need to drive it directly.

### Custom components

By default DynamicForm renders inputs, labels, and errors with its built-in
components. Point the library at your own components module — typically the
Phoenix-generated `MyAppWeb.CoreComponents` — globally:

```elixir
config :dynamic_form, components: MyAppWeb.CoreComponents
```

or per form (the attribute wins over the config):

```heex
<DynamicForm.form id="contact-form" components={MyAppWeb.CoreComponents}>
```

Dispatch is per function with fallback: each component the renderer needs is
looked up on your module, and anything it doesn't define renders through the
built-ins. A stock Phoenix 1.8 `CoreComponents` works out of the box — its
`input/1` takes over text, email, number, textarea, select, and checkbox
controls, `button/1` takes over the submit button, and `translate_error/1`
routes error messages through your app's Gettext — while radio groups,
checkbox groups, rating rows, panels, and the label/error pair around
custom-control slot bodies fall back to the built-ins unless your module
defines them (`input_radio_group/1`, `input_checkbox_group/1`, `section/1`,
`label/1`, `error/1`).

See `DynamicForm.Components` for the full contract and the assigns each
function receives, and the [Styling guide](styling.md) for the complete
styling story — including writing partial modules and per-field overrides.
A module that can't be loaded raises — a typo fails loudly rather than
silently rendering built-in styling. The Custom Components section of the
`/slot-forms` demo page shows delegation and fallback side by side in one
form.

### Custom field types

Applications can extend the built-in question types with their own — app
vocabulary like a `multiselect` or a `select_with_search` that shouldn't be
baked into the library. A custom field type is two things: a registry entry
declaring what the field *casts as*, and an `input/1` clause in the
[components module](#custom-components) declaring how it *renders*.

Register types globally, or per form with the `custom_field_types`
attribute (per-form entries merge over — and win against — the config):

```elixir
config :dynamic_form,
  custom_field_types: %{
    "multiselect" => {:array, :string},
    "select_with_search" => :string
  }
```

```heex
<DynamicForm.form id="signup" components={MyAppWeb.CoreComponents}>
  <:field type="select_with_search" name="school" label="School" options={@schools} required />
  <:field type="multiselect" name="days" label="Days" options={@days} />
</DynamicForm.form>
```

Rendering dispatches to the components module's `input/1` with the usual
assigns (`field`, `type`, `label`, `options`, `placeholder`, `disabled`) —
define a matching clause:

```elixir
def input(%{type: "select_with_search"} = assigns) do
  ~H"""
  <div class="fieldset mb-2" id={"#{@id}-combobox"} phx-hook="Combobox" phx-update="ignore">
    <span class="label mb-1">{@label}</span>
    <select name={@name} id={@id} class="w-full select">
      {Phoenix.HTML.Form.options_for_select(@options, @value)}
    </select>
  </div>
  """
end
```

The registered Ecto type drives the changeset: the field casts as declared,
and `{:array, _}` types get the same hidden-input normalization as the
built-in checkbox groups, so `required` works. `visible_if`/`required_if`
and the `validators` attribute apply as with any question; validation
beyond that is the application's job via `on_change`/`on_submit`.

Custom types work identically from data mode — `{"type": "multiselect",
"name": "days", "choices": ["mon", "tue"]}` — since the type name is just
data. Two failure modes to know: a question type that is neither built-in
nor registered renders **nothing** (obvious in testing, not broken-looking
in production), while a *registered* type without a matching `input/1`
clause falls to the module's catch-all and renders as a plain text input —
a graceful degradation that still round-trips the value.

## Lifecycle callbacks

Three optional hooks let the application participate in the form lifecycle:
`on_change` extends validation live as the user types (add
`on_change_debounce_in_ms` to run it after a pause instead of on every
keystroke), `on_submit` batches expensive submit-only checks (each receives a
`DynamicForm.Payload` and returns it), and `on_success` replaces the default
success message for forms that complete some other way.

They are documented in one place — the
[Lifecycle events guide](lifecycle.md) — with the signatures summarized in
the [Reference](reference.md#lifecycle-callback-contracts).

## File uploads

`type="file"` questions upload directly to cloud storage using presigned
URLs — files never pass through your server. Configuration lives in the
question's `metadata`:

```heex
<:field type="file" name="documents" label="Documents" metadata={%{
  "max_entries" => 3,
  "max_file_size" => 10_000_000,
  "accept" => ~w(.pdf .png .jpg),
  "bucket" => "my-uploads",
  "object_name_prefix" => "forms/",
  "presigner" => %{"module" => "MyApp.UploadPresigner", "function" => "sign"}
}} />
```

The presigner receives the client filename and a context map and returns the
presigned URL:

```elixir
defmodule MyApp.UploadPresigner do
  def sign(filename, %{bucket: bucket, prefix: prefix, field_name: _name}) do
    # Generate a presigned PUT URL for "#{prefix}#{filename}" in bucket
  end
end
```

On the client, register an uploader for the external upload in
`assets/js/app.js` (the demo app uses a stub that simulates success; a real
implementation PUTs the file to `entry.meta.url`):

```javascript
const GoogleStorage = (entries, onViewError) => {
  entries.forEach(entry => {
    // PUT the file to entry.meta.url, calling entry.progress(percent)
  })
}

const liveSocket = new LiveSocket("/live", Socket, {
  uploaders: {GoogleStorage},
  // ...
})
```

Completed uploads are stored in the form data as a list of maps with
`filename`, `cloud_bucket`, `cloud_path`, `cloud_provider`, and
`uploaded_on`. Deleting a file removes it from the form state only —
deleting the stored object is left to the application.

## Internationalization

Validation error messages translate through Gettext. Pass your app's Gettext
backend to use your own translations; otherwise the library's default
backend is used:

```heex
<DynamicForm.form id="contact-form" instance={@form_instance} gettext={MyAppWeb.Gettext} />
```
