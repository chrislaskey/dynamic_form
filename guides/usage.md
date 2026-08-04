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
<DynamicForm.form id="contact-form" title="Contact Form" send_messages>
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
<DynamicForm.form id="contact-form" json={@json} send_messages />
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
<DynamicForm.form id="contact-form" instance={@form_instance} send_messages />
```

Instances encode back to JSON with `Jason.encode!/1`, so definitions can be
stored in a database, served over an API, or cached.

See the [SurveyJS compatibility guide](surveyjs.md) for exactly which
SurveyJS features are supported, which are not (unsupported types render as
a visible fallback box), and DynamicForm's extensions to the format.

## Rendering

### `DynamicForm.form/1`

The unified entry point. Requires exactly one of the `instance` attribute
(data mode) or `<:field>` slots (declarative mode). Common options:

```heex
<DynamicForm.form
  id="profile-form"
  instance={@form_instance}
  params={%{"name" => "Jane"}}
  form_name="profile"
  submit_text="Save Profile"
  validation_summary="detailed"
  send_messages
/>
```

Internally it wraps `DynamicForm.RendererLive`, a LiveComponent that manages
the changeset, validation on change, and submission. Using the LiveComponent
directly with `<.live_component>` is equivalent.

### Edit mode

Pre-populate a form by passing `params`. Fields marked `read_only`
(`readOnly` in data mode) display their values but can't be edited — and
because browsers don't submit read-only/disabled inputs, the initial params
are merged back into every submission so those values survive validation:

```heex
<DynamicForm.form
  id="user-profile"
  instance={@form_instance}
  params={%{"id" => @user.id, "name" => @user.name, "email" => @user.email}}
  send_messages
/>
```

Extra keys in `params` that have no matching question (like `id` above) are
preserved through submission the same way.

### Messages

With `send_messages`, the component sends the parent LiveView a message on
every submission, carrying the outcome as an ok/error tuple —
`{:dynamic_form_submit, id, {:ok, payload} | {:error, payload}}`:

```elixir
def handle_info({:dynamic_form_submit, _id, {:ok, %{result: result}}}, socket) do
  # result is the on_submit return value, typically %{message: ..., data: ...}
  {:noreply, put_flash(socket, :info, result.message)}
end

def handle_info({:dynamic_form_submit, _id, {:error, %{changeset: changeset}}}, socket) do
  {:noreply, put_flash(socket, :error, "Please fix the errors below")}
end
```

Without `send_messages` the component is self-contained: it validates and
submits, and the parent is not notified. See the
[Lifecycle events guide](lifecycle.md) for the full lifecycle, actions, and
payloads.

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

### Stateless rendering

For full control over form state, skip the LiveComponent and use the pure
function component — your LiveView owns the changeset and the
`validate`/`submit` events:

```heex
<DynamicForm.Renderer.render
  instance={@form_instance}
  form={@form}
  phx_submit="submit"
  phx_change="validate"
  form_id="my-form"
/>
```

```elixir
def handle_event("validate", %{"form" => params}, socket) do
  changeset =
    socket.assigns.form_instance
    |> DynamicForm.Changeset.create_changeset(params)
    |> Map.put(:action, :validate)

  {:noreply, assign(socket, form: to_form(changeset, as: "form"))}
end
```

`DynamicForm.Changeset.create_changeset/2` builds the changeset from any
instance; the `/form-test` demo page shows the complete pattern.

## Lifecycle callbacks: `on_change` and `on_submit`

Two optional hooks mirror the form's `phx-change`/`phx-submit` events. Both
are 2-arity functions receiving `(changeset, data)`, where `data` is the
applied changeset data.

### `on_change` — extend validation

Runs after the built-in validations on every change (and during the submit
validation pass) and returns a changeset. Use it for cheap, synchronous
rules the built-in validators can't express — errors it adds render inline
live and clear as the user fixes fields:

```heex
<DynamicForm.form id="signup" on_change={&password_confirmation/2}>
```

```elixir
defp password_confirmation(changeset, data) do
  if data[:password] == data[:password_confirmation] do
    changeset
  else
    Ecto.Changeset.add_error(changeset, :password_confirmation, "does not match")
  end
end
```

Keep it cheap — it runs per keystroke.

### `on_submit` — expensive checks and the action

Runs on **every** submit — valid or not — so it can batch expensive checks
(third-party APIs, database lookups) with the built-in errors into one
complete error list, and decide whether to perform the action. Because it
also receives invalid changesets, gate on `changeset.valid?` before acting:

```heex
<DynamicForm.form id="contact-form" on_submit={&Contacts.submit/2} send_messages>
  <:field type="text" name="email" label="Email" required format="email" />
</DynamicForm.form>
```

```elixir
def submit(changeset, data) do
  changeset = verify_phone_number(changeset, data)   # expensive, submit-only

  if changeset.valid? do
    create_contact(data)                             # {:ok, _} | {:error, changeset}
  else
    {:error, changeset}
  end
end
```

The function must return:

- `{:ok, result}` — success; `result` flows to the parent in the `{:ok, _}`
  submit message.
- `{:error, %Ecto.Changeset{}}` — failure with field errors. A changeset
  derived from the form's own (the gate pattern above) is rendered directly;
  a foreign changeset — e.g. what a context returns for a uniqueness
  violation via `Repo.insert` — has its errors copied onto the form by
  field name.
- `{:error, reason}` — general failure; `reason` flows to the parent in the
  `{:error, _}` submit message.

Without `on_submit`, a valid submission succeeds with the form data alone —
pair with `send_messages` and do the work in the parent's `handle_info/2`
instead — and an invalid one renders its errors inline.

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
