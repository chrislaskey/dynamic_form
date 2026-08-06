# Nested Forms

A nested form is a repeating child form — a list of sub-records the user can
add and remove, like a contact with multiple addresses:

```elixir
%{name: "Ada", addresses: [%{street: "110 Main St", city: "Portland"}, ...]}
```

DynamicForm supports nested forms in both definition modes:

- **Data mode** — the SurveyJS
  [`paneldynamic`](https://surveyjs.io/form-library/documentation/api-reference/dynamic-panel-model)
  question type, decoded from JSON/maps.
- **Declarative mode** — `<:nested>` slot declarations inside
  `<DynamicForm.form>`.

Both converge on the same `Instance.Question{type: "paneldynamic"}` struct,
so validation, rendering, and submission behave identically.

## How it works

Every entry is validated with its own dynamic Ecto changeset built from the
template — the same schemaless-changeset machinery as the top-level form,
applied recursively (`DynamicForm.NestedForms`). There are no Ecto
relations, embedded schemas, or runtime-generated modules involved: entry
changesets are a pure function of the question and the form's current
params, so the validation pass and the renderer always see identical
errors. `isRequired`, `validators`, and conditional expressions all apply
per entry, and errors render inline inside the entry that caused them.

The rendered entries are namespaced sub-forms
(`dynamic_form[addresses][0][street]`), with add/remove buttons wired to
the managed component automatically. The submitted value is a list of maps
keyed by the template questions' names — matching SurveyJS's data shape.

## Data mode (SurveyJS `paneldynamic`)

```json
{
  "type": "paneldynamic",
  "name": "addresses",
  "title": "Addresses",
  "templateTitle": "Address {panelIndex}",
  "templateElements": [
    {"type": "dropdown", "name": "kind", "choices": ["Home", "Work", "Other"], "isRequired": true},
    {"type": "text", "name": "street", "title": "Street", "isRequired": true},
    {"type": "text", "name": "label", "title": "Label", "visibleIf": "{panel.kind} = 'Other'"}
  ],
  "panelCount": 1,
  "minPanelCount": 1,
  "maxPanelCount": 4,
  "addPanelText": "Add another address",
  "removePanelText": "Remove address",
  "confirmDelete": true,
  "keyName": "kind",
  "keyDuplicationError": "You already have an address of this type."
}
```

Supported properties: `templateElements` (alias `questions`),
`templateTitle` (with `{panelIndex}` interpolating the 1-based entry
number), `panelCount`, `minPanelCount`, `maxPanelCount`, `allowAddPanel`,
`allowRemovePanel`, `addPanelText` (alias `panelAddText`),
`removePanelText` (alias `panelRemoveText`), `noEntriesText`,
`confirmDelete`, `confirmDeleteText`, `keyName`, `keyDuplicationError`,
and `defaultPanelValue`.

## Declarative mode (`<:nested>` slots)

Because named slots can't nest in HEEx, the declarative syntax is flat and
reference-based — the same pattern as `<:group>`:

```heex
<DynamicForm.form id="contact-form">
  <:field type="text" name="name" label="Full name" required />

  <:nested name="addresses" title="Addresses" entry_title="Address {panelIndex}"
           entries={1} min_entries={1} max_entries={4}
           add_text="Add another address" key="kind" />
  <:field nested="addresses" type="dropdown" name="kind" label="Type"
          options={["Home", "Work", "Other"]} required />
  <:field nested="addresses" type="text" name="street" label="Street" required />
  <:field nested="addresses" type="text" name="label" label="Label"
          visible_if="{panel.kind} = 'Other'" />
</DynamicForm.form>
```

`<:nested>` attributes map to the SurveyJS question properties:
`entry_title` → `templateTitle`, `entries` → `panelCount` (entries seeded
on a fresh form), `min_entries`/`max_entries` →
`minPanelCount`/`maxPanelCount`, `add_text`/`remove_text`,
`no_entries_text`, `confirm_delete`/`confirm_text`, `key`/`key_error`,
`default` (a list of entry maps — edit-style initial value), and
`default_entry` (values seeded into each newly added entry). `required`,
`visible_if`, and `enable_if` work as on fields.

### The scope model: `nested` and `group` are orthogonal

- **`nested`** declares an entry's *data scope* — where its value lives.
  Absent means the top-level form; `nested="addresses"` means inside each
  entry of the `addresses` list.
- **`group`** declares *visual grouping* within whatever scope the entry
  is in. Groups never change the data shape.

The two combine. A group inside a nested form declares the scope **on both
ends** — on the `<:group>` declaration and on every member field — and any
mismatch raises at definition time (deliberate double-entry bookkeeping: a
forgotten attribute becomes an error instead of a silent data-shape
change):

```heex
<:nested name="addresses" title="Addresses" min_entries={1} />

<:group name="geo" title="Location" nested="addresses" />

<:field nested="addresses" type="dropdown" name="kind" options={["Home", "Work"]} />
<:field nested="addresses" group="geo" type="text" name="street" />
<:field nested="addresses" group="geo" type="text" name="city" />
```

Composition works in every direction except group-in-group (an existing
declarative-mode limitation):

| Composition | Spelling |
|---|---|
| Field in a nested form | `<:field nested="addresses">` |
| Group inside a nested form | `<:group nested="addresses">` + members declare both |
| Nested form inside a group | `<:nested group="section">` |
| Nested form inside a nested form | `<:nested name="phones" nested="contacts">` |

### Naming: unique per scope

Field and `<:nested>` names are **data keys**, unique *per scope* — the
top-level form is one scope, each nested form's template is another. So
names can mirror your schema (`user.name` alongside `addresses[].name`):

```heex
<:field type="text" name="name" label="Your name" />
<:field nested="addresses" type="text" name="name" label="Address nickname" />
```

`<:group>` and `<:nested>` *declaration* names are reference targets for
the flat `group=`/`nested=` attributes, so declarations are globally
unique per form.

### Custom controls per entry

Slot bodies work inside templates. The body receives the per-entry
`Phoenix.HTML.FormField` — the same closure renders once per entry with
each entry's name, value, and errors, while the library keeps the label,
error display, and changeset validation:

```heex
<:field :let={field} nested="milestones" type="text" name="effort"
        input_type="number" label="Effort (days)">
  <input type="range" min="1" max="30"
         name={field.name} id={field.id} value={field.value || 5} />
</:field>
```

## Conditional expressions and shadowing

Inside a template, expressions resolve **innermost-first**:

- `{panel.field}` explicitly references a sibling value in the same entry
  (SurveyJS's scoping prefix).
- A plain `{field}` reference resolves against the entry first, then the
  enclosing form — so when a template field shadows a top-level name, the
  entry's own value wins. Use distinct names if an expression inside a
  template needs the outer value.

`visibleIf`, `requiredIf`, and `enableIf` on template questions are
evaluated per entry, and hidden required questions are excluded from
validation as usual.

## Validation

Beyond per-entry validation of the template questions:

- `isRequired` on the nested question requires at least one entry.
- `minPanelCount`/`maxPanelCount` (`min_entries`/`max_entries`) validate
  the entry count on submit; the add/remove buttons also hide at the
  limits.
- `keyName` (`key`) enforces that one template field's value is unique
  across entries, erroring on each duplicate with `keyDuplicationError`
  (`key_error`).
- An invalid entry marks the parent changeset invalid; the parent-level
  error carries a `validation: :paneldynamic` marker and is suppressed
  from inline display (each entry shows its own errors).

## Entry lifecycle

- A fresh form seeds `panelCount`/`entries` entries (at least
  `minPanelCount`/`min_entries`); each is seeded from the template
  questions' `defaultValue`s merged with
  `defaultPanelValue`/`default_entry`.
- In edit mode, pass the list under the question's name in `data`:
  `data={%{"addresses" => [%{"street" => "110 Main St"}]}}`.
- `payload.data` on submission carries the applied nested value — a list
  of atom-keyed maps with cast values, entries omitting unanswered
  questions (matching SurveyJS).

## Standalone renderer events

`DynamicForm.form/1` and `DynamicForm.RendererLive` handle adding and
removing entries automatically. When driving `DynamicForm.Renderer`
manually, handle the events in your own LiveView:

- `"add_nested_entry"` with `%{"path" => path}`
- `"remove_nested_entry"` with `%{"path" => path, "index" => index}`

`path` is the dot-separated location of the nested question in the params
tree — `"addresses"` at the top level, `"contacts.0.phones"` inside
another nested form. `DynamicForm.NestedForms.find_question/2` resolves a
path to its question, and `DynamicForm.NestedForms.new_entry/1` builds a
seeded entry.

## Limitations

- File upload questions are not supported inside templates (declarative
  mode raises; data mode leaves the upload unconfigured).
- SurveyJS display modes other than the default list (`carousel`, `tab`)
  are not implemented, nor are `templateVisibleIf` or
  `{parentPanel.*}`/`{prevPanel.*}`/`{prevRow.*}` references.
- Matrix types (`matrixdynamic`) are not yet implemented — they share this
  feature's data shape and validation machinery and are a natural
  follow-up.
- Declarative mode: group-in-group remains unsupported, and `<:nested>`
  declaration names are globally unique (see Naming above).
