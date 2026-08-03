# Reference

Quick lookup tables. For narrative documentation see the
[Usage guide](usage.md).

## `DynamicForm.form/1` attributes

| Attribute | Type | Default | Description |
|---|---|---|---|
| `id` | string | required | Component ID; also the instance id in declarative mode |
| `instance` | any | `nil` | Data mode: `Instance` struct, JSON string, or map |
| `json` | string | `nil` | Data mode: SurveyJS-compatible JSON string, decoded via `Instance.decode!/1` |
| `title` | string | `nil` | Instance title (declarative mode) |
| `description` | string | `nil` | Instance description (declarative mode) |
| `backend` | any | `nil` | `Instance.Backend` struct for submission (declarative mode) |
| `params` | map | `%{}` | Initial form params for edit mode |
| `form_name` | string | `"dynamic_form"` | Form namespace for params |
| `submit_text` | string | `"Submit"` | Submit button text |
| `send_messages` | boolean | `false` | Send `{:dynamic_form_success, id, result}` to the parent LiveView |
| `hide_submit` | boolean | `false` | Hide the built-in submit button |
| `gettext` | atom | `DynamicForm.Gettext` | Gettext backend for translations |
| `validation_summary` | string | `nil` | Errors at top of form: `nil`, `"simple"`, or `"detailed"` |

Exactly one of `instance`, `json`, or `<:field>` slots must be provided.

`DynamicForm.RendererLive` (used directly via `<.live_component>`) accepts
`id`, `instance`, and the same optional attributes from `params` down.

## `<:field>` attributes

| Attribute | Type | Applies to | Description |
|---|---|---|---|
| `type` | string | all | Required. One of the question or element types below |
| `name` | string | all | Field name. Required for question types; auto-generated for `html`/`image`/`custom` |
| `label` | string | questions, `image` | Question title / image alt text (→ `title`) |
| `placeholder` | string | text inputs | Input placeholder |
| `description` | string | questions | Help text shown below the input |
| `input_type` | string | `text` | HTML input type pass-through (`email`, `number`, ...) |
| `default` | any | questions | Default value seeded into the form params (→ `defaultValue`) |
| `options` | list | choice types | Choices: `[{"Label", "value"}, ...]` or `["value", ...]` (→ `choices`) |
| `required` | boolean | questions | Required field (→ `isRequired`) |
| `required_if` | string | questions | Conditional requirement expression (→ `requiredIf`) |
| `visible_if` | string | all | Conditional visibility expression (→ `visibleIf`) |
| `enable_if` | string | all | Conditional enablement expression (→ `enableIf`) |
| `read_only` | boolean | questions | Display value without allowing edits (→ `readOnly`) |
| `group` | string | all | Collect this field into the `<:group>` panel with this name |
| `rate_min` / `rate_max` / `rate_step` | integer | `rating` | Rating scale (defaults 1–5, step 1) |
| `min_length` / `max_length` | integer | text | Builds a `text` validator |
| `min` / `max` | number | numeric | Builds a `numeric` validator |
| `pattern` | string | text | Builds a `regex` validator |
| `format` | string | text | Format validator; supported: `"email"` |
| `validators` | list | questions | Escape hatch: `Instance.Validator` structs or atom-keyed maps |
| `html` | string | `html` | Raw HTML content (alternative to a slot body) |
| `src` | string | `image` | Image URL (→ `imageLink`); required |
| `width` / `height` / `fit` | string | `image` | Image sizing (→ `imageWidth`/`imageHeight`/`imageFit`) |
| `metadata` | map | all | Metadata map (upload config, radiogroup style, ...) |

Slot bodies: any question type accepts a body receiving its
`Phoenix.HTML.FormField` via `:let`; `html` accepts a plain body;
`custom` requires a body receiving the Phoenix form.

## `<:group>` attributes

| Attribute | Type | Description |
|---|---|---|
| `name` | string | Required. Referenced by `<:field group="...">`; also the panel's name |
| `title` | string | Panel title |
| `visible_if` | string | Conditional visibility expression |
| `enable_if` | string | Conditional enablement (disables all contained questions when false) |

## Question types

| Type | Renders as | Notes |
|---|---|---|
| `text` | `<input>` | `input_type` passes through (`email`, `number`, ...); `number` casts to decimal |
| `comment` | `<textarea>` | |
| `dropdown` | `<select>` | Requires `options` |
| `radiogroup` | Radio buttons | Requires `options`; `metadata` `"style"`: `"vertical"`/`"horizontal"` |
| `checkbox` | Checkbox group | Array-valued; requires `options` |
| `tagbox` | Multi-select | Array-valued; requires `options` |
| `boolean` | Single checkbox | |
| `rating` | Numeric radio row | `rate_min`/`rate_max`/`rate_step`; casts to integer |
| `file` | Direct upload | Presigner + uploader required — see [Usage: File uploads](usage.md#file-uploads) |

## Element types

| Type | Renders as | Notes |
|---|---|---|
| `html` | Raw HTML or slot body | String attr goes through `Phoenix.HTML.raw/1`; slot bodies are escaped HEEx |
| `panel` | Titled container | Declared via `<:group>` in declarative mode; nestable in data mode |
| `image` | `<img>` | `src` required |
| `custom` | Slot body | Declarative-only; body receives the Phoenix form |

## Validators

Data-mode JSON validator objects (built automatically by the flattened attrs
in declarative mode). Each accepts a custom error message via `text`:

| Type | Fields | Flattened attrs |
|---|---|---|
| `text` | `minLength`, `maxLength` | `min_length`, `max_length` |
| `numeric` | `minValue`, `maxValue` | `min`, `max` |
| `email` | — | `format="email"` |
| `regex` | `regex` | `pattern` |

`input_type="email"` also applies email format validation automatically.

## Conditional expression operators

Used by `visible_if`, `required_if`, and `enable_if`:

| Category | Operators |
|---|---|
| Comparison | `=`, `==`, `<>`, `!=`, `>`, `<`, `>=`, `<=` |
| Presence | `empty`, `notempty` |
| Membership | `contains`, `notcontains`, `anyof`, `allof`, `noneof` |
| Combinators | `and`, `or`, parentheses |

Field references use braces: `{field_name}`. Literals: `'strings'`, numbers,
`true`/`false`, `['lists', 'of', 'values']`.

## Messages

Sent to the parent LiveView when `send_messages` is set:

| Message | When |
|---|---|
| `{:dynamic_form_success, component_id, result}` | Backend returned `{:cont, result}`, or no backend and the changeset was valid |

## Backend contract

`DynamicForm.Backend` behaviour; the function name is configurable via
`Instance.Backend`:

```elixir
@callback submit(form_data :: map(), changeset :: Ecto.Changeset.t(), config :: Keyword.t()) ::
            {:cont, map()} | {:halt, Ecto.Changeset.t()} | {:halt, map()}
@callback validate_config(config :: Keyword.t()) :: :ok | {:error, String.t()}
```

Called on every submission regardless of changeset validity.

## Upload metadata keys

`metadata` map keys for `type="file"` questions:

| Key | Default | Description |
|---|---|---|
| `"max_entries"` | `3` | Maximum number of files |
| `"max_file_size"` | `10_000_000` | Maximum file size in bytes |
| `"accept"` | `:any` | Accepted extensions/MIME types |
| `"bucket"` | — | Cloud storage bucket |
| `"object_name_prefix"` | `""` | Prefix for stored object names |
| `"presigner"` | — | `%{"module" => ..., "function" => ...}` returning a presigned URL |

Uploaded files are stored in the form data as maps with `filename`,
`cloud_bucket`, `cloud_path`, `cloud_provider`, and `uploaded_on`.

## Helper functions

| Function | Description |
|---|---|
| `DynamicForm.Instance.decode!/1` | JSON string or map → `Instance` struct |
| `DynamicForm.Instance.strip_slots/1` | Copy of an instance without slot bodies (definition-only comparison) |
| `DynamicForm.Instance.FromSlots.convert!/1` | Slot entries → `Instance` (used by `DynamicForm.form/1`) |
| `DynamicForm.Changeset.create_changeset/2` | Instance + params → Ecto changeset |
| `DynamicForm.Changeset.get_questions/1` | Flat list of questions, including nested panels |
| `DynamicForm.submit_button/1` | Submit button component usable outside the form element |
