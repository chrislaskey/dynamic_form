# Development

## Code conventions

- **Public API is what the USAGE and REFERENCE guides document.** Every other
  function — public or private — is internal and subject to change without
  notice. Cross-module calls justify a public function; they don't make it
  part of the API.
- **Function names use generic verbs**: `list_*` returns a collection,
  `get_*` returns one thing or `nil`, `create_*`/`update_*`/`delete_*` for
  the matching actions, predicates end in `?`. No
  `fetch_`/`find_`/`build_`/`retrieve_` synonyms for the same idea
  (`resolve_*` is reserved for the Components/FieldTypes override-resolution
  pattern). HEEx function components are named after the thing they render,
  not with CRUD verbs.
- `blank?` is the empty-value predicate everywhere; its exact semantics stay
  local to each module (e.g. `Instance.blank?/1` also treats `false` as
  blank, for labels).
- **One `alias` per line** — no `alias Foo.{Bar, Baz}` brace groups, and each
  contiguous alias block stays alphabetized.

## Demo app

The `/examples` directory contains a full Phoenix demo app exercising every
feature:

```
cd examples/demo
mix setup && iex -S mix phx.server
```

The demo is generated, following the same pattern as
[Slab](https://github.com/chrislaskey/slab):

- `examples/overlay/` — the version-controlled demo code: LiveViews, form
  definitions, layout tweaks, and tests. **This is where edits go.**
- `examples/demo/` — the generated app (committed, disposable). After editing
  the overlay, copy it over: `cp -R overlay/. demo/`, then run `mix format`
  inside `demo/` and copy any reformatted files back to the overlay so the
  two stay identical.
- `examples/regenerate.sh` — rebuilds `demo/` from scratch with a pinned
  `phx.new` release, applies DynamicForm-specific edits (path dependency,
  routes, Tailwind `@source`, a stub uploader
  for the direct-upload demo), and copies the overlay on top. Run it whenever
  the skeleton drifts out of date. Never edit generated files directly.

The `/slot-forms` page doubles as a manual test bed: each section shows the
definition above the rendered form, and the "Input Preservation Test" button
re-renders the parent LiveView to verify in-progress input survives (see the
update guard below).

## Architecture overview

Both definition modes converge on `DynamicForm.Instance` before any stateful
code runs:

```
JSON / stored map ──▶ Instance.Decoder ────┐
                                            ├──▶ %Instance{} ──▶ Renderer.LiveComponent ──▶ Renderer.Component
<:field> slots ─────▶ Instance.FromSlots ──┘
```

- `Instance.Decoder` normalizes untrusted external data (string keys, safe
  atom conversion); `Instance.FromSlots` normalizes compiler-produced slot
  entries (atom keys), with all declarative-mode validation in
  `Instance.FromSlots.Validator`. Conversion runs in the `DynamicForm.form/1`
  function component — the LiveComponent's contract stays "give me an
  Instance".
- **Slot carriage**: elements defined with a slot body keep the raw slot
  entry (including its `inner_block` closure) in their `:slot` field so the
  renderer can call `render_slot/2`. The `:slot` field is dropped from JSON
  encoding, and `Instance.strip_slots/1` removes it for definition-only
  comparison.
- **Update guard**: `Renderer.LiveComponent.update/2` fires on every parent re-render
  that touches its inputs and used to rebuild the changeset each time —
  wiping in-progress user input. It now skips re-initialization when the
  slot-stripped instance, initial params, and form name are unchanged, while
  still assigning the fresh instance so slot bodies re-render with current
  parent assigns.
- The original design document lives in `dynamic_form_library.md` at the repo
  root — it predates the SurveyJS migration, so its code examples use the old
  bespoke format, but the rationale still applies.

## Module map

Definition (building and querying an `%Instance{}`):

- `DynamicForm.Instance` — the structs (`Question`, `Element`, `Validator`)
  and their JSON encoding.
- `Instance.Decoder` — untrusted external data (JSON, string-keyed maps) →
  `%Instance{}`.
- `Instance.FromSlots` — slot entries → `%Instance{}`;
  `Instance.FromSlots.Validator` raises on definition mistakes and owns the
  slot type vocabulary.
- `Instance.Elements` — queries over the element tree (`list_questions/1`,
  `get_question/2`, `get_question_by_path/2`, ...). One scope rule
  everywhere: static panels are transparent, `templateElements` are their
  own scope.

Validation:

- `DynamicForm.Changeset` — instance + params → Ecto changeset.
- `DynamicForm.NestedForms` — entry machinery for `paneldynamic` questions:
  normalizing, seeding, entry changesets, entry-list validation.
- `DynamicForm.Visibility` — the SurveyJS conditional expression engine
  (`visibleIf`/`enableIf`/`requiredIf`) plus element filtering.
- `DynamicForm.CarryForward` — choices carried from another
  question: `resolve_choices/2` at render time, `prune_values/4` at cast time.

Rendering:

- `DynamicForm.Renderer.Component` — the form shell, element dispatch
  (`render_element/3`), and the per-question-type controls.
- `DynamicForm.Renderer.LiveComponent` — the stateful LiveComponent: lifecycle, events,
  callbacks, and messages. `Renderer.LiveComponent.Debounce` holds the change-pass
  timer/token mechanics.
- `Components.NestedEntries` / `Components.ContentElements` /
  `Components.ValidationSummary` — the paneldynamic sections, non-question
  elements, and error summary; they recurse back through
  `Renderer.Component.render_element/3`.
- `DynamicForm.CoreComponents` — the built-in UI components;
  `DynamicForm.Components` resolves per-function overrides from an app's own
  components module.
- `DynamicForm.DirectUpload` — the upload UI component and `sign/2`
  behaviour; `DirectUpload.Uploads` wires LiveView uploads per file question.

Directory layout: `contexts/` holds the domain logic (`instance/`,
`direct_upload/`, `carry_forward.ex`), `renderer/` the two renderers and the
debounce module, `components/` the function components, and `helpers/` the
generic plumbing (`Helpers.Map`, `Helpers.Form`) — mechanics only, with no
knowledge of questions or instances. Module names don't always mirror file
paths (`DynamicForm.CoreComponents` lives in `components/core_components.ex`),
the same way Phoenix organizes its own modules.

## Testing

Library tests (unit tests for conversion, changesets, visibility, rendering):

```
mix test
mix credo --all
mix format --check-formatted
```

Demo app tests (end-to-end LiveView tests: slot definitions, conditional
visibility, input preservation, submission handling, plus a smoke test over
every route):

```
cd examples/demo
mix test
```

## Documentation

`mix docs` generates API documentation including these guides. The README,
module docs, and guides should stay consistent — the README covers the
high-level pattern and installation, the guides cover depth, and module docs
cover per-function detail.
