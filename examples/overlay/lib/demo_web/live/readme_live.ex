defmodule DemoWeb.ReadmeLive do
  @moduledoc """
  The README's Examples section, live: each example shows its narrative,
  the exact code being rendered, and the rendered form itself. The code
  matches the README structurally — only the app-specific names differ
  (`Demo.Submissions` for `MyApp.Contacts`, `DemoWeb.CoreComponents` for
  `MyAppWeb.CoreComponents`, and unique form ids so the examples can share
  one page).
  """

  use DemoWeb, :live_view

  @example_basic ~S"""
  <DynamicForm.form id="readme-basic">
    <:field type="text" name="name" label="Name" required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />
  </DynamicForm.form>
  """

  @example_basic_handler ~S"""
  def handle_info({:dynamic_form, payload}, socket) do
    {:ok, contact} = Demo.Submissions.create(payload.data)
    {:noreply, put_flash(socket, :info, "Created contact")}
  end
  """

  @example_data ~S"""
  <DynamicForm.form id="readme-data" data={%{email: "hello@world.com"}}>
    <:field type="text" name="name" label="Name" required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />
  </DynamicForm.form>
  """

  @example_lifecycle ~S"""
  <DynamicForm.form id="readme-lifecycle" on_submit={&Demo.Submissions.verify/1}>
    <:field type="text" name="name" label="Name" required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />
  </DynamicForm.form>
  """

  @example_lifecycle_verify ~S"""
  def verify(payload) do
    if email_taken?(payload.data[:email]) do
      DynamicForm.Payload.add_error(payload, :email, "has already been taken")
    else
      payload
    end
  end
  """

  @example_support ~S"""
  <DynamicForm.form id="readme-support" on_submit={&Demo.Submissions.verify/1}>
    <:field type="text" name="name" label="Name" min_length={2} required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />

    <:field type="dropdown" name="subject" label="Subject" required
            options={[{"Support", "support"}, {"Sales", "sales"}]} />
    <:field type="comment" name="details" label="Support Details" visible_if="{subject} = 'support'" />
    <:field type="rating" name="satisfaction" label="Satisfaction" rate_min={1} rate_max={5} />
  </DynamicForm.form>
  """

  @example_styling ~S"""
  <DynamicForm.form id="readme-styling" on_submit={&Demo.Submissions.verify/1} components={DemoWeb.CoreComponents}>
    <:field type="text" name="name" label="Name" min_length={2} required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />

    <:field type="dropdown" name="subject" label="Subject" required
            options={[{"Support", "support"}, {"Sales", "sales"}]} />
    <:field type="comment" name="details" label="Support Details" visible_if="{subject} = 'support'" />

    <:field :let={field} type="rating" name="rating" label="Rating">
      <input type="range" min="1" max="5" step="1" name={field.name} id={field.id} value={field.value || 0} />
    </:field>
  </DynamicForm.form>
  """

  @example_grouping ~S"""
  <DynamicForm.form id="readme-grouping" on_submit={&Demo.Submissions.verify/1} components={DemoWeb.CoreComponents}>
    <:field type="text" name="name" label="Name" min_length={2} required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />

    <:field type="dropdown" name="subject" label="Subject" required
            options={[{"Support", "support"}, {"Sales", "sales"}]} />
    <:field type="comment" name="details" label="Support Details" visible_if="{subject} = 'support'" />

    <:field :let={field} type="rating" name="rating" label="Rating">
      <input type="range" min="1" max="5" step="1" name={field.name} id={field.id} value={field.value || 0} />
    </:field>

    <:field type="boolean" name="ship" label="Ship to a different address?" />
    <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
    <:field group="address" type="text" name="street" label="Street" required />
    <:field group="address" type="text" name="city" label="City" required />
  </DynamicForm.form>
  """

  @example_nested ~S"""
  <DynamicForm.form id="readme-nested" on_submit={&Demo.Submissions.verify/1} components={DemoWeb.CoreComponents}>
    <:field type="text" name="name" label="Name" min_length={2} required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />

    <:field type="dropdown" name="subject" label="Subject" required
            options={[{"Support", "support"}, {"Sales", "sales"}]} />
    <:field type="comment" name="details" label="Support Details" visible_if="{subject} = 'support'" />

    <:field :let={field} type="rating" name="rating" label="Rating">
      <input type="range" min="1" max="5" step="1" name={field.name} id={field.id} value={field.value || 0} />
    </:field>

    <:nested name="addresses" title="Addresses" entries={1} add_text="Add address" />
    <:field nested="addresses" type="text" name="street" label="Street" required />
    <:field nested="addresses" type="text" name="city" label="City" required />
  </DynamicForm.form>
  """

  @example_json_definition ~S"""
  {
    "title": "Example Form",
    "elements": [
      {"type": "text", "name": "name", "inputType": "text"},
      {"type": "text", "name": "email", "inputType": "email"}
    ]
  }
  """

  @example_json ~S"""
  <DynamicForm.form id="readme-json" json={@json} />
  """

  @example_render_only ~S"""
  <DynamicForm.form id="readme-render-only" form={@form} phx_change="validate" phx_submit="save" render_only>
    <:field type="text" name="name" label="Name" required />
    <:field type="text" name="email" label="Email" input_type="email" format="email" required />
  </DynamicForm.form>
  """

  @example_render_only_handlers ~S"""
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, to_form(changeset(%{}), as: "contact"))}
  end

  def handle_event("validate", %{"contact" => params}, socket) do
    form = params |> changeset() |> Map.put(:action, :validate) |> to_form(as: "contact")
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"contact" => params}, socket) do
    # the form lifecycle is entirely yours: insert, navigate, broadcast, ...
    {:noreply, put_flash(socket, :info, "Contact saved")}
  end
  """

  @pages [
    {"/slot-forms", "Slot-Based Form Definitions",
     "Declarative <DynamicForm.form> definitions in depth: <:field> slots, <:group> panels, custom markup via slot bodies, render-only mode (the parent owns the changeset and events), custom components, and custom field types"},
    {"/data-forms", "Data-Defined Forms",
     "Forms defined as SurveyJS-compatible data: JSON decoded from files, conditional visibility, panels, the struct/JSON toggle, external submit buttons, and create vs edit mode with data prefill and on_success"},
    {"/showcase-form", "Question Type Showcase",
     "Every supported question type on one form, including file uploads via a mock presigner"},
    {"/nested-forms", "Nested Forms (paneldynamic)",
     "Repeating child forms the user adds/removes — defined as SurveyJS JSON and as <:nested> slots, validated per entry"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       json: String.trim(@example_json_definition),
       pages: @pages,
       form: to_form(changeset(%{}), as: "contact"),
       example_basic: @example_basic,
       example_basic_handler: @example_basic_handler,
       example_data: @example_data,
       example_lifecycle: @example_lifecycle,
       example_lifecycle_verify: @example_lifecycle_verify,
       example_support: @example_support,
       example_styling: @example_styling,
       example_grouping: @example_grouping,
       example_nested: @example_nested,
       example_json_definition: @example_json_definition,
       example_json: @example_json,
       example_render_only: @example_render_only,
       example_render_only_handlers: @example_render_only_handlers
     )}
  end

  # Only valid submissions arrive here — invalid ones render their errors
  # inline on the form. This is where the side effect happens.
  @impl true
  def handle_info({:dynamic_form, %DynamicForm.Payload{} = payload}, socket) do
    {:ok, _result} = Demo.Submissions.create(payload.data)
    {:noreply, put_flash(socket, :info, "Form #{payload.id} submitted successfully")}
  end

  # Render-only mode: this LiveView owns the changeset and the events, just
  # like an idiomatic <form phx-change="validate" phx-submit="save">.
  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    form = params |> changeset() |> Map.put(:action, :validate) |> to_form(as: "contact")
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save", %{"contact" => params}, socket) do
    changeset = changeset(params)

    if changeset.valid? do
      {:noreply,
       socket
       |> assign(:form, to_form(changeset(%{}), as: "contact"))
       |> put_flash(:info, "Contact saved")}
    else
      form = changeset |> Map.put(:action, :validate) |> to_form(as: "contact")
      {:noreply, assign(socket, :form, form)}
    end
  end

  defp changeset(params) do
    {%{}, %{name: :string, email: :string}}
    |> Ecto.Changeset.cast(params, [:name, :email])
    |> Ecto.Changeset.validate_required([:name, :email])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <h1 class="text-3xl font-bold text-gray-900">DynamicForm</h1>
        <p class="mt-2 text-gray-600">
          Dynamic, changeset-backed forms for Phoenix LiveView — defined
          declaratively in HEEx or as (SurveyJS-compatible) data. This page is
          the <a
            href="https://github.com/chrislaskey/dynamic_form"
            class="font-semibold text-indigo-600 hover:text-indigo-500"
          >
            README
          </a>'s Examples section, running live.
        </p>

        <.example title="A simple form" code={@example_basic}>
          <:text>
            <p>
              Forms are defined using the
              <code class="bg-gray-100 px-1 rounded">&lt;DynamicForm.form /&gt;</code>
              component. It can either be defined in data or using component
              slots. The <code class="bg-gray-100 px-1 rounded">&lt;:field /&gt;</code>
              slots are rendered in the order they are defined.
            </p>
            <p>
              The library runs the whole validation lifecycle itself and
              messages the parent LiveView on every valid submission — the
              <code class="bg-gray-100 px-1 rounded">handle_info/2</code>
              handler is where the side effect happens. The
              <code class="bg-gray-100 px-1 rounded">payload</code>
              is a struct containing information about the form, including the
              <code class="bg-gray-100 px-1 rounded">data</code>
              key which is a map of the submitted data.
            </p>
          </:text>
          <DynamicForm.form id="readme-basic">
            <:field type="text" name="name" label="Name" required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
          </DynamicForm.form>
        </.example>

        <.code_block code={@example_basic_handler} class="mt-4" />

        <.example title="Prefilling form data" code={@example_data}>
          <:text>
            <p>
              Use the <code class="bg-gray-100 px-1 rounded">data</code>
              attribute to prefill the form with existing data:
            </p>
          </:text>
          <DynamicForm.form id="readme-data" data={%{email: "hello@world.com"}}>
            <:field type="text" name="name" label="Name" required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
          </DynamicForm.form>
        </.example>

        <.example title="Lifecycle hooks" code={@example_lifecycle}>
          <:text>
            <p>
              The <code class="bg-gray-100 px-1 rounded">on_submit</code>
              attribute mirrors <code class="bg-gray-100 px-1 rounded">phx-submit</code>:
              it runs on every submit — valid or not — so expensive checks
              (like the uniqueness lookup below) batch with the built-in errors
              into one complete list, rendered inline on the form. Try the
              email <code class="bg-gray-100 px-1 rounded">taken@example.com</code>
              to see it:
            </p>
          </:text>
          <DynamicForm.form id="readme-lifecycle" on_submit={&Demo.Submissions.verify/1}>
            <:field type="text" name="name" label="Name" required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
          </DynamicForm.form>
        </.example>

        <.code_block code={@example_lifecycle_verify} class="mt-4" />

        <p class="mt-4 text-gray-600">
          See the
          <a
            href="https://github.com/chrislaskey/dynamic_form/blob/main/guides/lifecycle.md"
            class="font-semibold text-indigo-600 hover:text-indigo-500"
          >
            Lifecycle guide
          </a>
          for more information on <code class="bg-gray-100 px-1 rounded">on_submit</code>, <code class="bg-gray-100 px-1 rounded">on_change</code>, and
          <code class="bg-gray-100 px-1 rounded">on_success</code>
          lifecycle hooks.
        </p>

        <.example title="Validation and visibility" code={@example_support}>
          <:text>
            <p>
              Layer in additional validation attrs and conditional visibility —
              the details field only appears when the subject is <code class="bg-gray-100 px-1 rounded">support</code>, and hidden
              required fields are excluded from validation automatically:
            </p>
          </:text>
          <DynamicForm.form id="readme-support" on_submit={&Demo.Submissions.verify/1}>
            <:field type="text" name="name" label="Name" min_length={2} required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
            <:field
              type="dropdown"
              name="subject"
              label="Subject"
              required
              options={[{"Support", "support"}, {"Sales", "sales"}]}
            />
            <:field
              type="comment"
              name="details"
              label="Support Details"
              visible_if="{subject} = 'support'"
            />
            <:field type="rating" name="satisfaction" label="Satisfaction" rate_min={1} rate_max={5} />
          </DynamicForm.form>
        </.example>

        <section class="mt-10 space-y-4">
          <h2 class="text-xl font-semibold text-gray-900">Styling and custom fields</h2>
          <div class="space-y-4 text-gray-600">
            <p>
              The library uses a version of the CoreComponents module that's
              generated by new Phoenix projects.
            </p>
            <p>
              It can be configured to use your project's custom components —
              either its version of CoreComponents or a custom module. It can
              be configured globally in config or per-form using the
              <code class="bg-gray-100 px-1 rounded">components</code>
              attribute.
            </p>
            <p>
              When using a custom component module, the library is smart enough
              to fall back to using the built-in version that ships with the
              library if a component is not defined in the custom module.
            </p>
            <p>
              Using a custom module is the preferred way to add custom fields
              as well as change the styling of the forms. There is also the
              ability to define custom markup using the slot body.
            </p>
            <p>
              See the
              <a
                href="https://github.com/chrislaskey/dynamic_form/blob/main/guides/styling.md"
                class="font-semibold text-indigo-600 hover:text-indigo-500"
              >
                Styling guide
              </a>
              for detailed information on custom inputs and styling.
            </p>
          </div>
          <.code_block code={@example_styling} />
          <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
            <DynamicForm.form
              id="readme-styling"
              on_submit={&Demo.Submissions.verify/1}
              components={DemoWeb.CoreComponents}
            >
              <:field type="text" name="name" label="Name" min_length={2} required />
              <:field
                type="text"
                name="email"
                label="Email"
                input_type="email"
                format="email"
                required
              />
              <:field
                type="dropdown"
                name="subject"
                label="Subject"
                required
                options={[{"Support", "support"}, {"Sales", "sales"}]}
              />
              <:field
                type="comment"
                name="details"
                label="Support Details"
                visible_if="{subject} = 'support'"
              />
              <:field :let={field} type="rating" name="rating" label="Rating">
                <input
                  type="range"
                  min="1"
                  max="5"
                  step="1"
                  name={field.name}
                  id={field.id}
                  value={field.value || 0}
                  class="mt-2 w-full accent-indigo-600"
                />
              </:field>
            </DynamicForm.form>
          </div>
        </section>

        <.example title="Grouping fields" code={@example_grouping}>
          <:text>
            <p>
              Group fields into panels, and take over rendering where you need
              to — here a custom range control via a slot body, while the
              library still owns the label, errors, and changeset validation:
            </p>
          </:text>
          <DynamicForm.form
            id="readme-grouping"
            on_submit={&Demo.Submissions.verify/1}
            components={DemoWeb.CoreComponents}
          >
            <:field type="text" name="name" label="Name" min_length={2} required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
            <:field
              type="dropdown"
              name="subject"
              label="Subject"
              required
              options={[{"Support", "support"}, {"Sales", "sales"}]}
            />
            <:field
              type="comment"
              name="details"
              label="Support Details"
              visible_if="{subject} = 'support'"
            />
            <:field :let={field} type="rating" name="rating" label="Rating">
              <input
                type="range"
                min="1"
                max="5"
                step="1"
                name={field.name}
                id={field.id}
                value={field.value || 0}
                class="mt-2 w-full accent-indigo-600"
              />
            </:field>

            <:field type="boolean" name="ship" label="Ship to a different address?" />
            <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
            <:field group="address" type="text" name="street" label="Street" required />
            <:field group="address" type="text" name="city" label="City" required />
          </DynamicForm.form>
        </.example>

        <.example title="Nested forms" code={@example_nested}>
          <:text>
            <p>
              Use nested forms to allow users to add multiple records in the
              same form.
            </p>
            <p>
              The user can add and remove entries. Each entry is validated with
              its own child changeset, and the submitted value arrives as a
              list of maps.
            </p>
            <p>
              See the
              <a
                href="https://github.com/chrislaskey/dynamic_form/blob/main/guides/nested-forms.md"
                class="font-semibold text-indigo-600 hover:text-indigo-500"
              >
                Nested forms guide
              </a>
              for entry seeding, min/max entry counts, and per-entry validation:
            </p>
          </:text>
          <DynamicForm.form
            id="readme-nested"
            on_submit={&Demo.Submissions.verify/1}
            components={DemoWeb.CoreComponents}
          >
            <:field type="text" name="name" label="Name" min_length={2} required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
            <:field
              type="dropdown"
              name="subject"
              label="Subject"
              required
              options={[{"Support", "support"}, {"Sales", "sales"}]}
            />
            <:field
              type="comment"
              name="details"
              label="Support Details"
              visible_if="{subject} = 'support'"
            />
            <:field :let={field} type="rating" name="rating" label="Rating">
              <input
                type="range"
                min="1"
                max="5"
                step="1"
                name={field.name}
                id={field.id}
                value={field.value || 0}
                class="mt-2 w-full accent-indigo-600"
              />
            </:field>

            <:nested name="addresses" title="Addresses" entries={1} add_text="Add address" />
            <:field nested="addresses" type="text" name="street" label="Street" required />
            <:field nested="addresses" type="text" name="city" label="City" required />
          </DynamicForm.form>
        </.example>

        <section class="mt-10 space-y-4">
          <h2 class="text-xl font-semibold text-gray-900">Define forms in data</h2>
          <p class="text-gray-600">
            Or define the same form as data. SurveyJS-compatible JSON passes
            straight in via the <code class="bg-gray-100 px-1 rounded">json</code>
            attribute, or decode it at the edge — from JSON, a map, or built as
            structs — and pass the instance to the same component:
          </p>
          <.code_block code={@example_json_definition} />
          <.code_block code={@example_json} />
          <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
            <DynamicForm.form id="readme-json" json={@json} />
          </div>
        </section>

        <.example title="Render only" code={@example_render_only}>
          <:text>
            <p>
              The library handles events and validations by default. These can
              be turned off if you prefer to just use the library as a renderer
              and to instead handle the actions yourself using the standard
              <code class="bg-gray-100 px-1 rounded">handle_event</code>
              handlers in the LiveView.
            </p>
            <p>
              Use the <code class="bg-gray-100 px-1 rounded">form</code>, <code class="bg-gray-100 px-1 rounded">phx_change</code>,
              <code class="bg-gray-100 px-1 rounded">phx_submit</code>
              and <code class="bg-gray-100 px-1 rounded">render_only</code>
              attributes to manage the lifecycle in the LiveView:
            </p>
          </:text>
          <DynamicForm.form
            id="readme-render-only"
            form={@form}
            phx_change="validate"
            phx_submit="save"
            render_only
          >
            <:field type="text" name="name" label="Name" required />
            <:field
              type="text"
              name="email"
              label="Email"
              input_type="email"
              format="email"
              required
            />
          </DynamicForm.form>
        </.example>

        <.code_block code={@example_render_only_handlers} class="mt-4" />

        <section class="mt-16 border-t border-zinc-100 pt-8">
          <h2 class="text-xl font-semibold text-gray-900">In-depth demo pages</h2>
          <p class="mt-2 text-gray-600">
            Each page below exercises one area of the library in depth, showing
            every definition alongside its rendered form.
          </p>
          <ul class="mt-4 divide-y divide-zinc-100">
            <li :for={{path, title, description} <- @pages} class="py-4">
              <.link navigate={path} class="group block">
                <span class="font-semibold text-indigo-600 group-hover:text-indigo-500">
                  {title} →
                </span>
                <p class="mt-1 text-sm text-gray-600">{description}</p>
                <code class="text-xs text-gray-400">{path}</code>
              </.link>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  attr :code, :string, required: true
  attr :title, :string, default: nil
  slot :text, required: true
  slot :inner_block, required: true

  defp example(assigns) do
    ~H"""
    <section class="mt-10 space-y-4">
      <h2 :if={@title} class="text-xl font-semibold text-gray-900">{@title}</h2>
      <div class="space-y-4 text-gray-600">{render_slot(@text)}</div>
      <.code_block code={@code} />
      <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :code, :string, required: true
  attr :class, :string, default: nil

  defp code_block(assigns) do
    ~H"""
    <pre class={[
      "p-4 rounded-lg bg-gray-50 border border-gray-200 text-sm text-zinc-700 overflow-x-auto",
      @class
    ]}><code>{String.trim(@code)}</code></pre>
    """
  end
end
