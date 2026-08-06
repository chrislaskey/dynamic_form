#!/usr/bin/env bash
#
# Regenerates the demo app from scratch:
#
#   1. Generates a fresh Phoenix app with `mix phx.new` (pinned version)
#   2. Applies DynamicForm-specific edits (path dep, routes, Tailwind, uploader)
#   3. Copies the demo code from overlay/ over the skeleton
#   4. Installs deps and builds assets
#
# Run it whenever the generated skeleton drifts out of date:
#
#   ./examples/regenerate.sh
#
# The interesting demo code lives in overlay/ (version controlled); the
# generated skeleton is disposable.

set -euo pipefail
cd "$(dirname "$0")"

PHX_NEW_VERSION="1.8.5"

# 1. Ensure the pinned Phoenix generator
if ! mix phx.new --version 2>/dev/null | grep -q "v${PHX_NEW_VERSION}$"; then
  echo "==> Installing phx_new ${PHX_NEW_VERSION}"
  mix archive.install hex phx_new "${PHX_NEW_VERSION}" --force
fi

# 2. Generate a fresh skeleton (no database needed)
echo "==> Generating demo app (phx.new ${PHX_NEW_VERSION})"
rm -rf demo
mix phx.new demo --module Demo --no-ecto --no-mailer --no-dashboard --no-gettext --no-install

# 3. DynamicForm-specific edits to generated files

echo "==> Adding dynamic_form as a path dependency"
perl -0777 -pi -e 's/(defp deps do\s*\n\s*\[\n)/$1      {:dynamic_form, path: "..\/.."},\n/' demo/mix.exs

echo "==> Replacing the default route with the demo LiveViews"
perl -pi -e 's{get "/", PageController, :home}{live "/", ReadmeLive\n    live "/slot-forms", SlotFormLive\n    live "/data-forms", DataFormLive\n    live "/showcase-form", ShowcaseFormLive\n    live "/nested-forms", NestedFormLive}' demo/lib/demo_web/router.ex

# The generated home page test asserts the default Phoenix marketing copy,
# but the route above replaced that page with the demo index
rm -f demo/test/demo_web/controllers/page_controller_test.exs

echo "==> Pointing Tailwind at DynamicForm's classes"
perl -pi -e 's{\@source "\.\./\.\./lib/demo_web";}{$&\n/* DynamicForm is a path dependency here, so point Tailwind at its source\n   directly. Apps installing dynamic_form from Hex use\n   "../../deps/dynamic_form/lib" instead. DynamicForm\x27s built-in components\n   use daisyUI classes, which phx.new 1.8+ vendors by default. */\n\@source "../../../../lib";}' demo/assets/css/app.css

echo "==> Registering a stub uploader for the direct-upload demo"
perl -0777 -pi -e 's{(const liveSocket = new LiveSocket)}{// Stub uploader for the direct-upload demo: simulates a successful upload\n// without a real cloud bucket. Real apps PUT the file to the presigned URL\n// in entry.meta.url. See DynamicForm.DirectUpload.\nconst GoogleStorage = (entries, _onViewError) => {\n  entries.forEach(entry => setTimeout(() => entry.progress(100), 300))\n}\n\n$1}' demo/assets/js/app.js
perl -pi -e 's{params: \{_csrf_token: csrfToken\},}{$&\n  uploaders: {GoogleStorage},}' demo/assets/js/app.js

# 4. Copy the demo code over the skeleton
echo "==> Applying overlay/"
cp -R overlay/. demo/

# 5. Install deps and build assets
echo "==> mix setup (deps, assets)"
(cd demo && mix setup)

echo
echo "Done. Run the demo with:"
echo
echo "    cd examples/demo && mix phx.server"
echo
echo "then open http://localhost:4000"
