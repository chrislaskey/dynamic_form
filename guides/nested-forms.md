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

Composition works in every direction:

| Composition | Spelling |
|---|---|
| Field in a nested form | `<:field nested="addresses">` |
| Group inside a nested form | `<:group nested="addresses">` + members declare both |
| Group inside a group | `<:group name="geo" group="section">` |
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

The field is scoped to its entry — `field.form[:title].value` reads a
sibling in the same entry. To read *outside* the entry, use
`DynamicForm.form_data/1`, which returns the whole form's current values
whatever scope the body is in, so a control in one nested form can build
itself from another's entries. See
[Reading the whole form from a body](usage.md#reading-the-whole-form-from-a-body).

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

## Entry ids

Entries are otherwise positional, so a value elsewhere in the form that
references one has nothing durable to point at: a member field changes when
the user edits it, and an index changes when entries are added or removed.
Every entry therefore carries a **`dynamic_form_id`**, seeded once and
round-tripped through a hidden input:

- an entry loaded from `data` with an `id` **adopts that id**, so references
  match the record the app already knows about;
- an entry the user adds this session gets a generated one;
- an entry that already has a `dynamic_form_id` keeps it.

It arrives in `payload.data` alongside the entry's own fields:

```elixir
%{staff: [%{dynamic_form_id: "42", name: "Ada"}]}
```

**The id is only stable across sessions if you persist it and pass it back
in `data`.** Without that, ids regenerate on reload and anything referencing
them silently points at nothing. Where entries map to stored records with
their own ids, that happens for free — the id is copied, not generated.

Set `generate_ids={false}` (`"generateIds": false` in data mode) on a nested
form that doesn't need identity, and no field is added to its entries.

## Entry position

Two ways to reach an entry's number, and they differ in base because they come
from different worlds:

**In a definition string**, `{panelIndex}` interpolates the **1-based** number —
SurveyJS's placeholder, so it matches what a SurveyJS definition expects:

```heex
<:nested name="age_groups" title="Age groups" entry_title="Group {panelIndex}" />
```

**In a slot body**, the entry's form carries its **0-based** position in
`index`, the same field Phoenix's own `inputs_for` populates for a collection:

```heex
<:field :let={form} nested="age_groups" type="custom" name="position">
  <div class="text-sm text-gray-500">Group {form.index + 1}</div>
</:field>
```

A control body reaches it through the field's form:

```heex
<:field :let={field} nested="age_groups" type="text" name="min" label="From">
  <input name={field.name} value={field.value} data-row={field.form.index} />
</:field>
```

`index` is `nil` on the form-level form — only entry forms have a position.
Note that it shifts when entries are added or removed, so it is a display
value, not an identity: use [`dynamic_form_id`](#entry-ids) for anything that
needs to keep pointing at the same entry.

## Choices from another nested form

A choice field can build its options from another question's entries —
SurveyJS calls this *carry forward*. Each program below picks which age
groups it serves, and the choices track the age groups as the user adds,
edits, and removes them:

```heex
<:nested name="age_groups" title="Age groups" min_entries={1} />
<:field nested="age_groups" type="dropdown" name="min" options={@months} required />
<:field nested="age_groups" type="dropdown" name="max" options={@months} required />

<:nested name="programs" title="Programs" />
<:field nested="programs" type="text" name="name" label="Name" required />
<:field nested="programs" type="checkbox" name="age_group_ids" label="Age groups"
        choices_from="age_groups" choice_text="{min} - {max}" />
```

- **`choices_from`** names the source nested form.
- **`choice_text`** labels each choice: a member field's name, or a template
  interpolating several — `{panelIndex}` gives the 1-based entry number.
  Required, since the alternative is labelling choices with opaque ids. An
  entry missing any interpolated field isn't offered as a choice, so a
  half-filled age group doesn't appear until it's complete.
- **`choice_value`** names the field supplying the stored value. It defaults
  to the entry's `dynamic_form_id`, which is what makes a selection survive
  the user editing the entry it points at.
- **`no_choices_text`** replaces the control entirely while the source has no
  entries to offer — the label stays, with your message under it, instead of
  an empty checkbox group:

  ```heex
  <:field nested="programs" type="checkbox" name="age_group_ids" label="Age groups"
          choices_from="age_groups" choice_text="{min} - {max}"
          no_choices_text="Add an age group above to assign it to this program." />
  ```

In data mode the same three are `choicesFromQuestion`,
`choiceTextsFromQuestion`, and `choiceValuesFromQuestion`.

Names resolve **innermost-first**: a source inside the same entry wins over a
form-level one of the same name. That's what makes per-entry sources work —
each team's lead chosen from that team's own members:

```heex
<:nested name="teams" title="Teams" />
<:nested nested="teams" name="members" title="Members" />
<:field nested="members" type="text" name="name" label="Name" required />
<:field nested="teams" type="dropdown" name="lead" label="Lead"
        choices_from="members" choice_text="{name}" />
```

### What happens to stale references

A value the source no longer offers is cleared during validation, so it never
reaches `payload.data`. That covers a deleted entry, an option removed from
the definition, and emptying the source entirely — the alternative would hand
your application a payload that contradicts itself, with ids pointing at
entries the same submission deletes.

Clearing a single-value field (a dropdown) empties it, so a `required` error
can appear without the user touching anything. It also happens on load, so
reopening a record whose stored value is no longer offered clears it before
the user sees the form.

Nothing is cleared when the form can't observe what the source offers:

- the definition has no such question — a hand-edited JSON definition, since
  declarative mode raises when `choices_from` names nothing;
- the submission carries no values for the source, as when `visible_if` hides
  it.

A source hidden by `visible_if` still supplies choices — its values are data
whether or not it renders.

### Carrying forward from another choice field

The source can also be an ordinary choice question rather than a nested form.
Its own options carry forward, optionally narrowed by what the user selected
there with `choices_mode` — `"all"` (default), `"selected"`, or
`"unselected"`:

```heex
<:field type="checkbox" name="languages" label="Languages you speak"
        options={[{"English", "en"}, {"Spanish", "es"}, {"Portuguese", "pt"}]} />
<:field type="dropdown" name="primary_language" label="Primary language"
        choices_from="languages" choices_mode="selected" />
```

`choice_text` and `choice_value` don't apply here — the source's options
already have a label and a value — and `choices_mode` doesn't apply to a
nested source, where every entry is a choice. Both raise if crossed. A value
the source stops offering is pruned, the same as a deleted entry.

### Render-only mode

The parent owns the changeset in [render-only
mode](usage.md#render-only-mode), so the entry-id seeding `DynamicForm.form/1`
does is the parent's job. Seed before building the changeset, or the default
value resolves to nothing:

```elixir
questions = DynamicForm.Changeset.list_questions(instance.elements)

changeset =
  params
  |> DynamicForm.NestedForms.seed_entry_ids(questions)
  |> then(&DynamicForm.Changeset.create_changeset(instance, &1))
```

Naming a real member field with `choice_value` avoids the seeding entirely,
at the cost of the stability ids give you. Pruning is also the parent's:
it runs inside `DynamicForm.Changeset.create_changeset/3`, so a hand-rolled
changeset keeps stale references.

### Persisting references

Selections are only meaningful as long as the ids they point at come back.
For a create flow, or one where the reference is consumed server-side and
never re-edited, generated ids are enough. **If a saved record is reopened
for editing, the source entries must return with the same ids** — persist
`dynamic_form_id`, or give the entries an `id` for the library to adopt.
Otherwise every reference is orphaned, and pruning deletes it on the first
change.

## The section header

A nested form renders as a section: `title` and `description` on the left, the
add button opposite them on the right, then the entries below. Both are
ordinary strings, so they can be translated at the call site:

```heex
<:nested
  name="age_groups"
  title={gettext("Age groups")}
  description={gettext("The age bands you sort children into.")}
  entry_title={gettext("Group {panelIndex}")}
/>
```

Omitting `title` falls back to the capitalized field name; setting it blank
(`nil`, `false`, or `""`) renders no heading at all, which is the way to get a
bare repeating list. The description is omitted when unset. The add button
hides at `max_entries`, which leaves the header as heading-only.

## Styling the entry container

Each repeating entry renders inside the `nested_entry/1` component — a
bordered card by default. Inside it, the entry is two columns: the entry
title (when `entry_title` is set) and the child fields on the left, and a
remove icon button on the right, top-aligned with the first field. The
right column collapses when the entry can't be removed, and the icon
button's tooltip and screen-reader label come from `remove_text`.

Define `nested_entry/1` on your [components module](styling.md) to restyle
the card; it receives `index`, the question `name`, and that two-column
frame as `inner_block`:

```elixir
def nested_entry(assigns) do
  ~H"""
  <div class="mt-3 border-l-4 border-indigo-300 bg-indigo-50/50 p-4">
    {render_slot(@inner_block)}
  </div>
  """
end
```

## Standalone renderer events

`DynamicForm.form/1` and `DynamicForm.Renderer.LiveComponent` handle adding and
removing entries automatically. When driving `DynamicForm.Renderer.Component`
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
- Declarative mode: `<:group>` and `<:nested>` declaration names are
  globally unique (see Naming above).
