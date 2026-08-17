# Changelog

All notable changes to this project are documented here. For releases before
0.19.0, see the git history.

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

### Added

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

- A choice field no longer requires an `options` list when it has a slot body
  rendering its own choices, or a `choices_from` source.

### Fixed

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
