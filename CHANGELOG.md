# Changelog

All notable changes to this project are documented here. For releases before
0.19.0, see the git history.

## 0.20.0

### Added

- `DynamicForm.form_data/1`: inside a `<:field>` slot body, the whole form's
  current values as a map — the same shape as `payload.data`. Always
  form-level, so a control inside one nested form can read another's
  entries.

### Fixed

- Read-only values are no longer dropped inside nested entries. `readOnly`
  rendered as an HTML `disabled` input, which browsers don't submit, and the
  initial-data merge that covered for that restores top-level keys only — so
  a read-only value inside a nested entry was lost on the first change. Text
  controls now render `readonly` (still submitted), and controls HTML has no
  `readonly` for render disabled alongside a hidden input carrying the value.
  Questions disabled by `enableIf` are unaffected: they remain excluded from
  the params.
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
