defmodule DemoWeb.ReadmeLive do
  @moduledoc """
  The README's Examples section, live: each example shows its narrative,
  the exact code being rendered, and the rendered form itself. The code
  matches the README structurally — only the app-specific names differ
  (`Demo.Submissions` for `MyApp.Contacts`, and unique form ids so the
  examples can share one page).
  """

  use DemoWeb, :live_view

  @example_contact ~S"""
  <DynamicForm.form id="readme-contact" on_submit={&Demo.Submissions.verify/1}>
    <:field type="text" name="name" label="Name" required />
    <:field type="text" name="email" input_type="email" label="Email Address" required format="email" />
  </DynamicForm.form>
  """

  @example_contact_handlers ~S"""
  # In Demo.Submissions — the on_submit callback runs on every submit:
  def verify(payload) do
    if email_taken?(payload.data[:email]) do
      DynamicForm.Payload.add_error(payload, :email, "has already been taken")
    else
      payload
    end
  end

  # In the parent LiveView — only valid submissions arrive here:
  def handle_info({:dynamic_form, %DynamicForm.Payload{data: data}}, socket) do
    {:ok, contact} = Demo.Submissions.create(data)
    {:noreply, put_flash(socket, :info, "Created contact")}
  end
  """

  @example_support ~S"""
  <DynamicForm.form id="readme-support">
    <:field type="text" name="name" label="Name" required min_length={2} />
    <:field type="dropdown" name="subject" label="Subject" required
            options={[{"Support", "support"}, {"Sales", "sales"}]} />
    <:field type="comment" name="details" label="Support Details" visible_if="{subject} = 'support'" />
    <:field type="rating" name="satisfaction" label="Satisfaction" rate_min={1} rate_max={5} />
  </DynamicForm.form>
  """

  @example_checkout ~S"""
  <DynamicForm.form id="readme-checkout">
    <:field type="boolean" name="ship" label="Ship to a different address?" />

    <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
    <:field group="address" type="text" name="street" label="Street" required />
    <:field group="address" type="text" name="city" label="City" required />

    <:field :let={field} type="text" name="budget" input_type="number" label="Budget">
      <input type="range" min="0" max="1000" step="50" name={field.name} id={field.id} value={field.value || 0} />
    </:field>
  </DynamicForm.form>
  """

  @example_json_definition ~S"""
  {
    "title": "Contact Form",
    "elements": [
      {"type": "text", "name": "name", "inputType": "text"},
      {"type": "text", "name": "email", "inputType": "email"}
    ]
  }
  """

  @example_json ~S"""
  <DynamicForm.form id="readme-json" json={@json} />
  """

  @example_data ~S"""
  <DynamicForm.form id="readme-data" json={@json} data={%{email: "hello@world.com"}} />
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
       example_contact: @example_contact,
       example_contact_handlers: @example_contact_handlers,
       example_support: @example_support,
       example_checkout: @example_checkout,
       example_json_definition: @example_json_definition,
       example_json: @example_json,
       example_data: @example_data
     )}
  end

  # Only valid submissions arrive here — invalid ones render their errors
  # inline on the form. This is where the side effect happens.
  @impl true
  def handle_info({:dynamic_form, %DynamicForm.Payload{} = payload}, socket) do
    {:ok, _result} = Demo.Submissions.create(payload.data)
    {:noreply, put_flash(socket, :info, "Form #{payload.id} submitted successfully")}
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

        <.example code={@example_contact}>
          <:text>
            A form is a component call with fields in render order. The library
            runs the whole validation lifecycle itself and messages the parent
            LiveView on every valid submission — the
            <code class="bg-gray-100 px-1 rounded">handle_info/2</code>
            handler is where the side effect happens:
          </:text>
          <DynamicForm.form id="readme-contact" on_submit={&Demo.Submissions.verify/1}>
            <:field type="text" name="name" label="Name" required />
            <:field
              type="text"
              name="email"
              input_type="email"
              label="Email Address"
              required
              format="email"
            />
          </DynamicForm.form>
        </.example>

        <section class="mt-6 space-y-4">
          <p class="text-gray-600">
            <code class="bg-gray-100 px-1 rounded">on_submit</code>
            mirrors <code class="bg-gray-100 px-1 rounded">phx-submit</code>: it
            runs on every submit — valid or not — so expensive checks (like a
            uniqueness lookup) batch with the built-in errors into one complete
            list, rendered inline on the form. Try the email
            <code class="bg-gray-100 px-1 rounded">taken@example.com</code>
            above to see it. An <code class="bg-gray-100 px-1 rounded">on_change</code>
            callback extends validation live as the user types the same way.
          </p>
          <.code_block code={@example_contact_handlers} />
        </section>

        <.example code={@example_support}>
          <:text>
            Layer in validation attrs and conditional visibility — the details
            field only appears when the subject is <code class="bg-gray-100 px-1 rounded">support</code>, and hidden
            required fields are excluded from validation automatically:
          </:text>
          <DynamicForm.form id="readme-support">
            <:field type="text" name="name" label="Name" required min_length={2} />
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

        <.example code={@example_checkout}>
          <:text>
            Group fields into panels, and take over rendering where you need to
            — here a custom range control via a slot body, while the library
            still owns the label, errors, and changeset validation:
          </:text>
          <DynamicForm.form id="readme-checkout">
            <:field type="boolean" name="ship" label="Ship to a different address?" />

            <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
            <:field group="address" type="text" name="street" label="Street" required />
            <:field group="address" type="text" name="city" label="City" required />

            <:field :let={field} type="text" name="budget" input_type="number" label="Budget">
              <input
                type="range"
                min="0"
                max="1000"
                step="50"
                name={field.name}
                id={field.id}
                value={field.value || 0}
                class="mt-2 w-full accent-indigo-600"
              />
            </:field>
          </DynamicForm.form>
        </.example>

        <section class="mt-10 space-y-4">
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

        <.example code={@example_data}>
          <:text>
            Use the <code class="bg-gray-100 px-1 rounded">data</code>
            attribute to prefill the form with existing data:
          </:text>
          <DynamicForm.form id="readme-data" json={@json} data={%{email: "hello@world.com"}} />
        </.example>

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
  slot :text, required: true
  slot :inner_block, required: true

  defp example(assigns) do
    ~H"""
    <section class="mt-10 space-y-4">
      <p class="text-gray-600">{render_slot(@text)}</p>
      <.code_block code={@code} />
      <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  attr :code, :string, required: true

  defp code_block(assigns) do
    ~H"""
    <pre class="p-4 rounded-lg bg-gray-50 border border-gray-200 text-sm text-zinc-700 overflow-x-auto"><code>{String.trim(@code)}</code></pre>
    """
  end
end
