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
| `on_change` | function | `nil` | 1-arity `(payload) -> payload`, after built-in validations on every change and during the submit validation pass |
| `on_submit` | function | `nil` | 1-arity `(payload) -> payload`, on every submit — valid or not |
| `on_success` | function | `nil` | 1-arity `(payload)`, on every valid submission — replaces the default `{:dynamic_form, payload}` message |
| `data` | map | `%{}` | Initial form data for edit mode — existing record values; a payload's `data` round-trips directly |
| `form_name` | string | `"dynamic_form"` | Form namespace for params |
| `submit_text` | string | `"Submit"` | Submit button text |
| `hide_submit` | boolean | `false` | Hide the built-in submit button |
| `gettext` | atom | `DynamicForm.Gettext` | Gettext backend for translations |
| `components` | atom | `nil` | Custom components module; falls back to the `:dynamic_form, :components` config, then the built-ins per function |
| `custom_field_types` | map | `nil` | Custom field types (`%{"name" => ecto_type}`), merged over the `:dynamic_form, :custom_field_types` config |
| `validation_summary` | string | `nil` | Errors at top of form: `nil`, `"simple"`, or `"detailed"` |
| `render_only` | boolean | `false` | Render markup only: events go to the parent LiveView's `handle_event/3`; requires `form` |
| `form` | `Phoenix.HTML.Form` | `nil` | Render-only mode: the parent-owned form to render against |
| `phx_change` | string | `"validate"` | Render-only mode: change event name |
| `phx_submit` | string | `"submit"` | Render-only mode: submit event name |

Exactly one of `instance`, `json`, or `<:field>` slots must be provided.
`render_only` excludes the lifecycle attributes (`on_change`, `on_submit`,
`on_success`, `data`, `form_name`, `validation_summary`) and file upload
questions — both raise.

`DynamicForm.RendererLive` (used directly via `<.live_component>`) accepts
`id`, `instance`, and the same optional attributes from `data` down.

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
| `nested` | string | all except `file` | Data scope: collect this field into the `<:nested>` form with this name — see the [Nested Forms guide](nested-forms.md) |
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
| `nested` | string | Data scope this group lives in; every member field must declare the identical scope |

## `<:nested>` attributes

Declares a repeating child form (→ a SurveyJS `paneldynamic` question);
fields join it with `<:field nested="...">`. See the
[Nested Forms guide](nested-forms.md).

| Attribute | Type | Description |
|---|---|---|
| `name` | string | Required. Data key — the value is a list of entry maps |
| `title` / `description` | string | Heading and help text |
| `entry_title` | string | Per-entry heading; `{panelIndex}` interpolates the 1-based number (→ `templateTitle`) |
| `entries` | integer | Entries seeded on a fresh form (→ `panelCount`) |
| `min_entries` / `max_entries` | integer | Count limits: buttons hide, and submit validates (→ `minPanelCount`/`maxPanelCount`) |
| `add_text` / `remove_text` | string | Button labels (→ `addPanelText`/`removePanelText`) |
| `no_entries_text` | string | Shown at zero entries (→ `noEntriesText`) |
| `confirm_delete` / `confirm_text` | boolean / string | Confirmation before removing (→ `confirmDelete`/`confirmDeleteText`) |
| `key` / `key_error` | string | Member field unique across entries + error message (→ `keyName`/`keyDuplicationError`) |
| `default` | list | Initial value: list of entry maps (→ `defaultValue`) |
| `default_entry` | map | Values seeded into each newly added entry (→ `defaultPanelValue`) |
| `required` | boolean | At least one entry required (→ `isRequired`) |
| `visible_if` / `enable_if` | string | Conditional expressions |
| `nested` | string | Place this nested form inside another `<:nested>` form |
| `group` | string | Place this nested form inside a `<:group>` panel |

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
| `paneldynamic` | Repeating child form | Casts to a list of maps, validated per entry; `<:nested>` in declarative mode — see [Nested Forms](nested-forms.md) |

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

Sent to the parent LiveView by default, on **valid** submissions only —
invalid submissions render their errors inline and never message the parent.
Defining `on_success` replaces the message with the callback:

```elixir
{:dynamic_form, %DynamicForm.Payload{}}
```

`%DynamicForm.Payload{}` fields:

| Field | Value |
|---|---|
| `id` | The form component's id |
| `changeset` | The form's final `Ecto.Changeset`; its `valid?` flag is the source of truth for validity (always `true` for delivered messages) |
| `data` | The applied changeset data |
| `extra` | Empty map by default; written by `on_submit` via `Payload.put_extra/3` |

## Lifecycle callback contracts

```elixir
on_change:  (DynamicForm.Payload.t()) -> DynamicForm.Payload.t()
on_submit:  (DynamicForm.Payload.t()) -> DynamicForm.Payload.t()
on_success: (DynamicForm.Payload.t()) -> any()
```

`on_change` runs after built-in validations, on every change and during the
submit validation pass. `on_submit` runs on every submit — valid or not —
so it can batch expensive checks with the built-in errors into one complete
error list. Both are validation hooks that run *alongside* the built-in
behavior: reject a submission with `DynamicForm.Payload.add_error/4`
(validity lives on the changeset, so adding an error marks the submission
invalid); perform side effects in the parent's `handle_info/2` instead.

`on_success` runs on every valid submission and *replaces* the default
`{:dynamic_form, payload}` message; its return value is ignored.

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

## Custom field types

Registered as `%{"type_name" => ecto_type}` via the
`:dynamic_form, :custom_field_types` config and/or the `custom_field_types`
attribute (per-form entries win). The Ecto type drives casting (`{:array, _}`
types get checkbox-group-style param normalization); rendering dispatches to
the components module's `input/1`, matched by a
`def input(%{type: "type_name"} = assigns)` clause. Names colliding with
built-in types raise. Unregistered question types render nothing.

## Components contract

Functions the renderer dispatches through the `components` module
(per-function fallback to `DynamicForm.CoreComponents`):

| Function | Renders | In Phoenix-generated CoreComponents? |
|---|---|---|
| `input/1` | text/email/number, textarea, select, checkbox controls | yes — works out of the box |
| `input_radio_group/1` | radiogroup and rating questions | no — built-in fallback |
| `input_checkbox_group/1` | multi-select checkbox groups | no — built-in fallback |
| `label/1`, `error/1` | around custom-control slot bodies | no — built-in fallback |
| `section/1` | panels | no — built-in fallback |
| `button/1` | the submit button | yes — delegates |
| `translate_error/1` | error messages via the app's Gettext | yes — delegates |

## Helper functions

| Function | Description |
|---|---|
| `DynamicForm.Instance.decode!/1` | JSON string or map → `Instance` struct |
| `DynamicForm.Instance.strip_slots/1` | Copy of an instance without slot bodies (definition-only comparison) |
| `DynamicForm.Instance.FromSlots.convert!/1` | Slot entries → `Instance` (used by `DynamicForm.form/1`) |
| `DynamicForm.Changeset.create_changeset/2` | Instance + params → Ecto changeset |
| `DynamicForm.Changeset.get_questions/1` | Flat list of questions, including nested panels |
| `DynamicForm.Payload.add_error/4` | Add a changeset error, marking the submission invalid |
| `DynamicForm.Payload.put_extra/3` | Stash derived data on the payload for the parent's `handle_info/2` |
| `DynamicForm.submit_button/1` | Submit button component usable outside the form element |
