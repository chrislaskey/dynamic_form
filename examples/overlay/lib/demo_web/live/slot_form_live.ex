defmodule DemoWeb.SlotFormLive do
  @moduledoc """
  Test page for declarative slot-based form definitions via `DynamicForm.form/1`.

  Demonstrates:
  - Basic `<:field>` definitions (types, validation attrs, visible_if)
  - Groups rendered as panels via `<:group>` + `group="..."`
  - Custom markup tiers: html slot bodies, custom controls with `:let={field}`,
    and fully custom elements with `:let={form}`
  - Input preservation across parent re-renders (the RendererLive
    definition-equality guard)
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  # Definition snippets shown above each rendered form. They match the
  # markup in render/1 structurally — only surrounding page chrome differs.
  @src_basic ~S"""
  <DynamicForm.form
    id="basic-slot-form"
    title="Contact Form"
    on_submit={&Demo.Submissions.submit/2}
    send_messages
  >
    <:field type="text" name="name" label="Name" required min_length={2} />
    <:field type="text" name="email" input_type="email" label="Email Address"
            placeholder="you@example.com" required format="email" />
    <:field type="dropdown" name="subject" label="Subject" required
            options={[{"Support", "support"}, {"Sales", "sales"}, {"Other", "other"}]} />
    <:field type="comment" name="details" label="Support Details"
            description="Only visible when subject is Support"
            visible_if="{subject} = 'support'" />
    <:field type="rating" name="satisfaction" label="Satisfaction" rate_min={1} rate_max={5} />
    <:field type="boolean" name="subscribe" label="Subscribe to the newsletter" />
  </DynamicForm.form>
  """

  @src_groups ~S"""
  <DynamicForm.form id="group-slot-form" send_messages>
    <:field type="text" name="recipient" label="Recipient" required />
    <:field type="boolean" name="ship" label="Ship to a different address?" />

    <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
    <:field group="address" type="text" name="street" label="Street" required />
    <:field group="address" type="text" name="city" label="City" required />
    <:field group="address" type="dropdown" name="state" label="State"
            options={["CO", "NY", "CA"]} />

    <:field type="comment" name="delivery_notes" label="Delivery Notes" />
  </DynamicForm.form>
  """

  @src_custom ~S"""
  <DynamicForm.form id="custom-slot-form" on_change={&budget_per_attendee/2} send_messages>
    <%!-- Tier 1: html slot body reading parent assigns --%>
    <:field type="html" name="intro">
      <div class="rounded-md bg-indigo-50 p-4">
        <h3 class="font-semibold text-indigo-900">Welcome to {@company_name}</h3>
        <p class="text-sm text-indigo-700">
          Parent re-render count: <strong>{@render_count}</strong>
        </p>
      </div>
    </:field>

    <:field type="text" name="attendees" input_type="number" label="Attendees"
            required min={1} max={20} />

    <%!-- Tier 2: custom control receives the FormField; label, errors, and
         validation still come from the library --%>
    <:field :let={field} type="text" name="budget" input_type="number"
            label="Budget (custom range control)">
      <input type="range" min="0" max="1000" step="50"
             name={field.name} id={field.id} value={field.value || 0}
             class="mt-2 w-full accent-indigo-600" />
      <p class="mt-1 text-sm text-gray-600">Selected: ${field.value || 0}</p>
    </:field>

    <%!-- Tier 3: fully custom element receives the Phoenix form --%>
    <:field :let={form} type="custom" name="summary">
      <div class="rounded-md bg-gray-50 p-4 text-sm text-gray-700">
        <p class="font-semibold text-gray-900">Live summary (fully custom element)</p>
        <p>
          Registering <strong>{Phoenix.HTML.Form.input_value(form, :attendees) || 0}</strong>
          attendee(s) with a budget of
          <strong>${Phoenix.HTML.Form.input_value(form, :budget) || 0}</strong>.
        </p>
      </div>
    </:field>
  </DynamicForm.form>
  """

  @src_data ~S"""
  <DynamicForm.form
    id="data-mode-form"
    instance={Demo.FormInstances.contact_form()}
    send_messages
  />
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       company_name: "Acme Corp",
       render_count: 0,
       results: %{},
       src_basic: @src_basic,
       src_groups: @src_groups,
       src_custom: @src_custom,
       src_data: @src_data
     )}
  end

  @impl true
  def handle_event("bump_render_count", _params, socket) do
    {:noreply, update(socket, :render_count, &(&1 + 1))}
  end

  # An on_change callback: a cheap cross-field rule the built-in validators
  # can't express, validated live as the user types.
  defp budget_per_attendee(changeset, data) do
    attendees = data[:attendees]
    budget = data[:budget]

    if attendees && budget && Decimal.compare(budget, Decimal.mult(attendees, 50)) == :lt do
      Ecto.Changeset.add_error(changeset, :budget, "must be at least $50 per attendee")
    else
      changeset
    end
  end

  @impl true
  def handle_info({:dynamic_form_submit, id, {:ok, payload}}, socket) do
    {:noreply,
     socket
     |> update(:results, &Map.put(&1, id, payload))
     |> put_flash(:info, "Form #{id} submitted successfully")}
  end

  @impl true
  def handle_info({:dynamic_form_submit, id, {:error, _payload}}, socket) do
    {:noreply, put_flash(socket, :error, "Form #{id} has errors — see below")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Slot-Based Form Definitions</h1>
          <p class="mt-2 text-gray-600">
            These forms are defined declaratively in the template with
            <code class="bg-gray-100 px-2 py-1 rounded">&lt;DynamicForm.form&gt;</code>
            and <code class="bg-gray-100 px-2 py-1 rounded">&lt;:field&gt;</code>
            slots instead of instance data.
          </p>
        </div>

        <%!-- Parent re-render test control --%>
        <div class="mb-8 p-4 bg-amber-50 border border-amber-200 rounded-lg">
          <h3 class="font-semibold text-amber-900">Input Preservation Test</h3>
          <p class="mt-1 text-sm text-amber-800">
            Type into any form below, then click this button. The parent LiveView
            re-renders (the count appears inside a slot body in form 3), but your
            in-progress input should survive thanks to the definition-equality
            guard in <code>RendererLive</code>.
          </p>
          <button
            phx-click="bump_render_count"
            class="mt-3 rounded-md bg-amber-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-amber-500"
          >
            Re-render parent (count: {@render_count})
          </button>
        </div>

        <%!-- 1. Basic form --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">1. Basic Fields</h2>
        <p class="text-sm text-gray-500 mb-6">
          Question types, flattened validators (<code>format</code>, <code>min_length</code>),
          and <code>visible_if</code> (pick subject "Support" to reveal details).
          Submits through <code>on_submit={"{&Demo.Submissions.submit/2}"}</code> —
          try the email <code>taken@example.com</code> to see a context error render
          on the form.
        </p>

        <.definition title="Template definition" code={@src_basic} />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form
            id="basic-slot-form"
            title="Contact Form"
            on_submit={&Demo.Submissions.submit/2}
            send_messages
          >
            <:field type="text" name="name" label="Name" required min_length={2} />
            <:field
              type="text"
              name="email"
              input_type="email"
              label="Email Address"
              placeholder="you@example.com"
              required
              format="email"
            />
            <:field
              type="dropdown"
              name="subject"
              label="Subject"
              options={[{"Support", "support"}, {"Sales", "sales"}, {"Other", "other"}]}
              required
            />
            <:field
              type="comment"
              name="details"
              label="Support Details"
              description="Only visible when subject is Support"
              visible_if="{subject} = 'support'"
            />
            <:field type="rating" name="satisfaction" label="Satisfaction" rate_min={1} rate_max={5} />
            <:field type="boolean" name="subscribe" label="Subscribe to the newsletter" />
          </DynamicForm.form>
        </div>

        <%!-- 2. Groups --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">2. Groups (Panels)</h2>
        <p class="text-sm text-gray-500 mb-6">
          Fields with <code>group="address"</code>
          collect into a panel declared by <code>&lt;:group&gt;</code>. Toggle the checkbox to reveal it — the panel
          renders at the position of its first member field. Required fields inside
          a hidden group are excluded from validation.
        </p>

        <.definition title="Template definition" code={@src_groups} />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form id="group-slot-form" send_messages>
            <:field type="text" name="recipient" label="Recipient" required />
            <:field type="boolean" name="ship" label="Ship to a different address?" />

            <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
            <:field group="address" type="text" name="street" label="Street" required />
            <:field group="address" type="text" name="city" label="City" required />
            <:field
              group="address"
              type="dropdown"
              name="state"
              label="State"
              options={["CO", "NY", "CA"]}
            />

            <:field type="comment" name="delivery_notes" label="Delivery Notes" />
          </DynamicForm.form>
        </div>

        <%!-- 3. Custom markup --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">3. Custom Markup (Slot Bodies)</h2>
        <p class="text-sm text-gray-500 mb-6">
          Three tiers: an html body reading parent assigns, a custom control via
          <code>:let={"{field}"}</code>
          (library keeps label + errors + validation),
          and a fully custom element via <code>:let={"{form}"}</code>.
          Also demonstrates <code>on_change</code>
          — a live cross-field rule
          (after submitting once, set attendees to 5 and budget below $250 to
          see it, then fix it and watch the error clear in realtime).
        </p>

        <.definition title="Template definition" code={@src_custom} />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form id="custom-slot-form" on_change={&budget_per_attendee/2} send_messages>
            <:field type="html" name="intro">
              <div class="rounded-md bg-indigo-50 p-4">
                <h3 class="font-semibold text-indigo-900">
                  Welcome to {@company_name}
                </h3>
                <p class="text-sm text-indigo-700">
                  This block is a HEEx slot body reading parent assigns.
                  Parent re-render count: <strong>{@render_count}</strong>
                </p>
              </div>
            </:field>

            <:field
              type="text"
              name="attendees"
              input_type="number"
              label="Attendees"
              required
              min={1}
              max={20}
            />

            <:field
              :let={field}
              type="text"
              name="budget"
              input_type="number"
              label="Budget (custom range control)"
            >
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
              <p class="mt-1 text-sm text-gray-600">
                Selected: ${field.value || 0} — a native range input wired to the
                changeset field; validation and errors still come from the library.
              </p>
            </:field>

            <:field :let={form} type="custom" name="summary">
              <div class="rounded-md bg-gray-50 p-4 text-sm text-gray-700">
                <p class="font-semibold text-gray-900">Live summary (fully custom element)</p>
                <p>
                  Registering <strong>{Phoenix.HTML.Form.input_value(form, :attendees) || 0}</strong>
                  attendee(s) with a budget of <strong>${Phoenix.HTML.Form.input_value(form, :budget) || 0}</strong>.
                </p>
              </div>
            </:field>
          </DynamicForm.form>
        </div>

        <%!-- 4. Data mode through the same component --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">4. Data Mode, Same Entry Point</h2>
        <p class="text-sm text-gray-500 mb-6">
          The same <code>&lt;DynamicForm.form&gt;</code>
          component accepts an <code>instance</code>
          attribute instead of slots — here the shared
          contact form instance used by the other test pages.
        </p>

        <.definition
          title="Template definition"
          subtitle="The instance itself is shown on the Renderer and Component pages"
          code={@src_data}
        />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form
            id="data-mode-form"
            instance={Demo.FormInstances.contact_form()}
            send_messages
          />
        </div>

        <%!-- Submission results --%>
        <div :if={@results != %{}} class="mt-8 rounded-lg bg-green-50 p-6">
          <h3 class="text-lg font-semibold text-green-900 mb-4">Submission Results</h3>
          <div :for={{id, result} <- @results} class="mb-4 text-sm text-green-800">
            <p class="font-semibold">{id}</p>
            <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(result, pretty: true) %></pre>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
