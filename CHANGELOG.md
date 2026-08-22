# Changelog

All notable changes to this project are documented here. For releases before
0.19.0, see the git history.

## 0.24.0

### Internal refactor

Undocumented public functions are internal (see the new Conventions section
in the Development guide) and several were renamed or moved with no
deprecation path:

- `DynamicForm.Instance.FromSlots` → `DynamicForm.Parser.Declarative`
  (including the documented `convert!/1`) and
  `Instance.FromSlots.Validator` → `Parser.Declarative.Validator`
- `DynamicForm.Instance.Decoder` → `DynamicForm.Parser.JSON`
- `NestedForms.entries/1` → `NestedForms.list_entries/1`
- `NestedForms.entry_changesets/3` → `NestedForms.list_entry_changesets/3`
- `Changeset.build_types_map/2` → `Changeset.create_types_map/2`
- `Instance.decode!/1` now also accepts an already-decoded `%Instance{}`
  (pass-through)

## 0.23.0

### Breaking

- A required field's mark is no longer composed into its label. `label` now
  arrives at a components module as plain text, and the mark comes alongside
  it as two new assigns, `required` and `required_label`, for the component to
  render where it likes. `input/1`, `input_radio_group/1`,
  `input_checkbox_group/1`, and `label/1` all receive both. **A custom
  components module keeps rendering, but silently stops showing marks until it
  renders them** — nothing raises. See
  [Styling: the required mark](styling.md#the-required-mark).
- `required` now renders the HTML `required` attribute on the control, so the
  browser enforces it alongside the server. A field left empty is blocked by
  the browser before `phx-submit` fires, which means `on_submit` does not run
  and no server-rendered errors appear for that attempt. Checkbox *groups* are
  excluded: `required` on each box would demand every option rather than one.

### Added

- `required_label` on `<:field>` and `<:nested>` sets the mark beside a required
  label — `"(required)"` instead of
  `"*"`, say. Blank (`nil`, `false`, or `""`) shows no mark while the field
  stays required on both client and server; unset gives `"*"`. SurveyJS spells
  the same idea `requiredMark` and sets it once per survey, so reading it per
  question is our extension — that name is accepted as a decoding alias and
  appears nowhere else.
- A required checkbox now shows a mark beside its inline label; it never did
  before.

- Nested form entries carry their position in the form's `index` field, so a
  slot body can display it: `{form.index + 1}` in a `type="custom"` body, or
  `field.form.index` in a control body. Zero-based, matching the field
  Phoenix's own `inputs_for` populates for a collection — the `{panelIndex}`
  placeholder stays one-based for SurveyJS compatibility. `nil` on the
  form-level form, since only entries have a position.
- A `<:group>` can sit inside another `<:group>`, by naming it the same way a
  field names its group — panel-in-panel is no longer data-mode only. Each
  level keeps its own `type`, so a stacked group can hold a row. A parent
  renders at the position of its earliest member, including one contributed by
  a child group, and a nested group must declare the same `nested` scope as
  its parent so a form-level panel can't sit inside an entry-scoped one.
  Cyclic references, self-references, and groups naming an undeclared parent
  raise at conversion time.

## 0.22.0

### Added

- Carry forward (SurveyJS's `choicesFromQuestion`): a choice field can build
  its options from a `<:nested>` form's entries with `choices_from`, labelled
  by `choice_text` — a member field's name or a template interpolating
  several (`"{min} - {max}"`, `"{panelIndex}"`). Values default to the
  entry's `dynamic_form_id`, so a selection survives edits to the entry it
  points at. Source names resolve innermost-first, so a nested form inside
  the same entry wins over a form-level one of the same name.
- `no_choices_text` replaces a carried-forward field's control while its
  source has no entries yet, so an empty checkbox group can say "Add an age
  group above to assign it here" instead of rendering nothing.
- Carry forward from another **choice field**, not just a nested form: its
  options carry over, narrowed by `choices_mode` — `"all"` (default),
  `"selected"`, or `"unselected"` (SurveyJS's `choicesFromQuestionMode`).
- Values a carried-forward source no longer offers are cleared during
  validation — a deleted entry, an option removed from the definition, or the
  source emptied entirely. Nothing is cleared when the form can't observe the
  source: no such question in the definition, or a submission that carries no
  values for it (hidden by `visible_if`, say).

- `<:group type="...">` (`"groupType"` in JSON) picks a group's layout:
  `"horizontal"` (default) puts its members on one row, wrapping as needed,
  and `"vertical"` stacks them. Members are sized by their content rather
  than split into equal columns, so a `<:field>` slot body can set an exact
  width and the row honors it. Applications add their own types by defining
  `dynamic_form_group/1` — it dispatches on `type` exactly like `input/1`.

### Breaking

- The components-module function wrapping a group is `dynamic_form_group/1`,
  not `section/1`. It receives `type`, `title`, `name`, and `disabled`
  alongside `inner_block`. As with `input/1`, a module that exports it owns
  every group type, so end with a clause delegating to
  `DynamicForm.CoreComponents.dynamic_form_group/1`.
- Groups arrange their members on one row by default. Existing groups that
  should keep stacking need `type="vertical"`.

### Changed

- `label` and `title` accept a blank value — `nil`, `false`, or `""` — meaning
  "render no label", so a template can compute one without special-casing
  (`label={@compact && gettext("Street")}`). A blank label suppresses the
  required marker with it: `required` still validates, but an asterisk with
  nothing to sit beside isn't rendered. Applies to `<:field label>`,
  `<:group title>`, `<:nested title>` and `<:nested entry_title>`, in data mode
  as well as declarative. Omitting the attribute is unchanged and still falls
  back to the capitalized field name; the attrs are typed `:any` rather than
  `:string` to allow `false`.
- A nested form renders as a section: its `title` (now an `<h3>`) and
  `description` on the left, its add button opposite them on the right rather
  than below the entries. The title no longer routes through the components
  module's `label/1` — a repeating section is a heading, not a label for a
  single input.
- A nested form's add button renders through the components module's
  `button/1` instead of raw markup, so it picks up the application's button
  styling like the submit button does. It receives its `phx-click` in `rest`,
  so a custom `button/1` must splat globals (`<button {@rest}>`). Both button
  dispatches now pass the same assigns: `type`, `disabled`, `rest`,
  `inner_block`.
- A nested-form entry is laid out in two columns: its title and child fields
  on the left, its remove control on the right, top-aligned with the first
  field. The control is a trash icon rather than a text button, and its
  column collapses when the entry can't be removed — so an untitled entry
  spends no vertical space on a header row at all. `remove_text`
  (`removePanelText`) still applies, now as the icon's tooltip and
  screen-reader name. The icon is an inline SVG rather than a `hero-*` class,
  so it renders in apps that don't vendor heroicons.
- A choice field no longer requires an `options` list when it has a slot body
  rendering its own choices, or a `choices_from` source.

### Fixed

- A question's title and description are escaped when composed with the
  library's own markup. Building the required marker and a checkbox's inline
  description interpolated them into a raw HTML string, so a definition loaded
  from storage could inject markup into the page. A title deliberately wrapped
  in `Phoenix.HTML.raw/1` still renders as markup, which is now the way to opt
  in. Every other title and description already went through HEEx and was
  never affected.
- Fields inside a `<:group>` render like fields anywhere else. The group's
  contents took a shortcut past the wrapper every other field goes through,
  so two things silently didn't work inside one: `no_choices_text` never
  replaced an empty carried-forward control, and a read-only choice field
  lost the hidden input carrying its value — so it was dropped on the next
  change.

## 0.21.0

### Added

- Nested form entries carry a stable `dynamic_form_id`, so a value
  referencing an entry survives edits and reordering. An entry loaded from
  `data` with an `id` adopts it; one the user adds gets a generated id. The
  field round-trips through a hidden input and appears in `payload.data` —
  it is only stable across sessions if the application persists it and
  passes it back in `data`. Opt out per nested form with
  `generate_ids={false}` (`"generateIds": false`).

### Fixed

- Hiding a section no longer rewinds it to the data the form was loaded
  with. A section hidden by `visible_if` submits nothing, and the gap was
  being filled from the original `data` — discarding edits made while it was
  visible, and its entries' ids along with them. The gap is now filled from
  what the form is currently holding, falling back to the loaded data only
  for keys the form has never held. A question disabled by `enable_if` keeps
  its last value for the same reason, rather than reverting. Still section by
  section: a question hidden *inside* a repeating entry loses its value.
- Read-only values are no longer dropped inside nested entries. `readOnly`
  rendered as an HTML `disabled` input, which browsers don't submit, and the
  initial-data merge that covered for that restores top-level keys only — so
  a read-only value inside a nested entry was lost on the first change. Text
  controls now render `readonly` (still submitted), and controls HTML has no
  `readonly` for render disabled alongside a hidden input carrying the value.
  Questions disabled by `enableIf` are unaffected: they remain excluded from
  the params.

## 0.20.0

### Added

- `DynamicForm.form_data/1`: inside a `<:field>` slot body, the whole form's
  current values as a map — the same shape as `payload.data`. Always
  form-level, so a control inside one nested form can read another's
  entries.

### Fixed

- The Usage guide's `type="custom"` example bound `:let={field}` and read
  `field.form`. That body receives the form itself, so the example raised
  `KeyError` as written.

## 0.19.0

### Breaking

- Parent LiveView messages carry the lifecycle event:
  `{:dynamic_form, payload}` is now `{:dynamic_form, event, payload}`. Update
  existing handlers to `handle_info({:dynamic_form, :success, payload}, socket)` —
  an unmatched message raises `FunctionClauseError` rather than failing quietly.
- `:change` and `:submit` payloads can be invalid. The previous guarantee that
  the parent only ever hears about valid submissions holds for `:success` only.

### Added

- `send_message_on` attribute: the lifecycle events that message the parent
  LiveView, any of `[:success, :change, :submit]` (default: `[:success]`).
  Listing `:success` alongside `on_success` raises, since `on_success`
  replaces that message.
- `change_debounce_in_ms` attribute: milliseconds of quiet before a change
  runs `on_change` and sends its `:change` message. The built-in validations
  still render on every change, and submitting always runs the change pass
  inline.

### Changed

- Adding or removing a nested entry now runs the change pass — `on_change`
  and the `:change` message — like any other change to the form's data.
