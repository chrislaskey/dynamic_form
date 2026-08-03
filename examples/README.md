# DynamicForm demo app

A full Phoenix application exercising DynamicForm — no database or external
services required.

## Running it

```
cd examples/demo
mix setup
mix phx.server
```

Then open [http://localhost:4000](http://localhost:4000). The home page
lists every demo:

- `/slot-forms` — declarative `<DynamicForm.form>` definitions: `<:field>`
  slots, `<:group>` panels, custom markup (slot bodies), data mode through
  the same component, and an input-preservation test across parent re-renders
- `/form-test-component` — `DynamicForm.RendererLive` usage modes and
  external submit buttons
- `/form-test` — the stateless `DynamicForm.Renderer` with manual state
  management
- `/render` — create vs edit mode
- `/showcase-form` — every question type, including file uploads (a stub JS
  uploader and `Demo.MockUrlPresigner` simulate cloud storage)
- `/payment-form`, `/section-form` — conditional visibility and panels
- `/surveyjs-test` — SurveyJS JSON decoding
- `/builder-mockups` — WYSIWYG builder mockups

## Layout

- `demo/` — the generated app. The interesting files are:
  - `lib/demo_web/live/slot_form_live.ex` — the declarative slot-based API
  - `lib/demo/form_instances.ex` — data-mode form definitions shared by the
    other pages
  - `lib/demo/test_backend.ex` — a `DynamicForm.Backend` that logs
    submissions
  - `assets/css/app.css` — the Tailwind `@source` line (pointing at
    DynamicForm's source directly, since the demo uses a path dependency;
    Hex-installed apps use `../../deps/dynamic_form/lib`) and the
    `@plugin "@tailwindcss/forms"` line DynamicForm's input styling relies on
  - `assets/js/app.js` — the stub `GoogleStorage` uploader for the
    direct-upload demo
- `overlay/` — the DynamicForm-specific demo code, copied over the generated
  skeleton by the regenerate script
- `regenerate.sh` — regenerates `demo/` from scratch with a pinned
  `phx.new` version, reapplies the edits and overlay, and builds assets.
  Run it whenever the skeleton drifts out of date.

## Distribution note

Apps depending on `dynamic_form` (path or git dependency) never compile any
of this — dependencies only compile the library's `lib/`. The directory is a
few hundred KB of text riding along in the repo.
