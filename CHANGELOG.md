# Changelog

All notable changes to this project are documented here. For releases before
0.19.0, see the git history.

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
