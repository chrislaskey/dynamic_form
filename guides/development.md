# Development

## Architecture overview

There are four major pieces to DynamicForm:

- Parsing the inputs
- Defining the instance
- Rendering the instance
- Managing the lifecycle (skipped if using `render_only`)

Visualized, it looks like:

```
JSON / stored map ──▶ Parser.JSON ─────────┐
                                           ├──▶ %Instance{} ──▶ Renderer ──▶ Lifecycle
<:field> slots ─────▶ Parser.Declarative ──┘
```

## Code conventions

- **Public API is what the USAGE and REFERENCE guides document.** Every other
  function — public or private — is internal and subject to change without
  notice. Cross-module calls justify a public function; they don't make it
  part of the API.
- **Function names use generic verbs**: `list_*` returns a collection,
  `get_*` returns one thing or `nil`, `create_*`/`update_*`/`delete_*` for
  the matching actions, predicates end in `?`. No
  `fetch_`/`find_`/`build_`/`retrieve_` synonyms for the same idea
  (`resolve_*` is reserved for the ComponentResolver/FieldTypes override-resolution
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

## Code notes

- `Parser.JSON` normalizes untrusted external data (string keys, safe
  atom conversion); `Parser.Declarative` normalizes compiler-produced slot
  entries (atom keys), with all declarative-mode validation in
  `Parser.Declarative.Validator`. Conversion runs in the `DynamicForm.form/1`
  function component — the LiveComponent's contract stays "give me an
  Instance".
- **Slots**: elements defined with a slot body keep the raw slot
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
