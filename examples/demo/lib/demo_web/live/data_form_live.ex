defmodule DemoWeb.DataFormLive do
  @moduledoc """
  Data-defined forms: the same `<DynamicForm.form>` component driven by
  SurveyJS-compatible data instead of `<:field>` slots.

  Demonstrates the full data story in three sections:
  - JSON decoded from a file, with conditional visibility (`visibleIf`)
  - Instance structs with panels, the struct/JSON toggle showing both
    formats render identically, and an external submit button
  - Create vs edit mode: the same definition prefilled via `data`, a
    `readOnly` field, and an `on_success` callback replacing the default
    `{:dynamic_form, :success, payload}` message
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  alias DynamicForm.Instance

  @impl true
  def mount(_params, _session, socket) do
    payment_json = File.read!(Path.join(:code.priv_dir(:demo), "surveyjs_payment_form.json"))
    section_form = Demo.FormInstances.section_form()
    contact_form = Demo.FormInstances.contact_form()

    {:ok,
     assign(socket,
       payment_json: payment_json,
       payment_form: Instance.decode!(payment_json),
       section_form: section_form,
       section_json: Jason.encode!(section_form),
       section_json_pretty: Jason.encode!(section_form, pretty: true),
       use_json: true,
       contact_form: contact_form,
       edit_form: disable_email_field(contact_form),
       mode: :create,
       results: %{}
     )}
  end

  # Toggle between passing the panels form as a JSON string vs structs
  @impl true
  def handle_event("toggle_format", _params, socket) do
    {:noreply, assign(socket, :use_json, !socket.assigns.use_json)}
  end

  @impl true
  def handle_event("change_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, String.to_existing_atom(mode))}
  end

  # Default lifecycle: only valid submissions arrive here — invalid ones
  # render their errors inline. This is where the side effect happens.
  @impl true
  def handle_info({:dynamic_form, :success, %DynamicForm.Payload{} = payload}, socket) do
    {:ok, result} = Demo.Submissions.create(payload.data)

    {:noreply,
     socket
     |> update(:results, &Map.put(&1, payload.id, result.data))
     |> put_flash(:info, "Form #{payload.id} submitted successfully")}
  end

  # The edit-mode form's on_success callback sends this instead of the
  # default {:dynamic_form, :success, payload} message
  @impl true
  def handle_info({:contact_updated, data}, socket) do
    {:noreply,
     socket
     |> update(:results, &Map.put(&1, "contact-edit", data))
     |> put_flash(:info, "Contact updated (via on_success)")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Data-Defined Forms</h1>
          <p class="mt-2 text-gray-600">
            The same <code class="bg-gray-100 px-2 py-1 rounded">&lt;DynamicForm.form&gt;</code>
            component, driven by SurveyJS-compatible data instead of
            <code class="bg-gray-100 px-2 py-1 rounded">&lt;:field&gt;</code>
            slots — for forms stored in a database, generated at runtime, or
            built in a WYSIWYG editor. JSON strings, maps, and
            <code class="bg-gray-100 px-2 py-1 rounded">%Instance{"{}"}</code>
            structs all converge on the same struct, so validation,
            conditional logic, and submission behave identically.
          </p>
        </div>

        <%!-- 1. JSON from a file + conditional visibility --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">
          1. JSON Definitions and Conditional Visibility
        </h2>
        <p class="text-sm text-gray-500 mb-6">
          This payment form is decoded from a SurveyJS-compatible JSON file with
          <code>DynamicForm.Instance.decode!/1</code>
          and passed via the <code>instance</code>
          attribute. Change the payment
          method to see <code>visibleIf</code>
          expressions like <code>{"{payment_method}"} = 'credit_card'</code>
          reveal the matching
          fields — hidden required fields are excluded from validation.
        </p>

        <.definition
          title="Form Definition (JSON)"
          subtitle="priv/surveyjs_payment_form.json, decoded at mount"
          code={@payment_json}
        />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form id="payment-form" instance={@payment_form} submit_text="Process Payment" />
        </div>

        <%!-- 2. Panels via structs, with the JSON/struct toggle --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">2. Panels (Sections)</h2>
        <p class="text-sm text-gray-500 mb-6">
          Panel elements group questions into titled cards, nest inside each
          other, and support conditional visibility (subscribe to the
          newsletter to reveal the frequency dropdown). This form also uses <code>hide_submit</code>
          with an external <code>&lt;DynamicForm.submit_button&gt;</code>
          connected by the HTML <code>form</code>
          attribute — place it in a sticky footer, modal header, anywhere.
        </p>

        <div class="mb-6 rounded-lg bg-indigo-50 border border-indigo-200 p-4">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-semibold text-indigo-900">Instance Format</h3>
              <p class="mt-1 text-xs text-indigo-700">
                Toggle which format is passed to the component — both render identically
              </p>
            </div>
            <button
              phx-click="toggle_format"
              class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500"
            >
              {if @use_json, do: "Using json={@json_string}", else: "Using instance={@structs}"}
            </button>
          </div>
        </div>

        <.definition
          title={"Form Definition (#{if @use_json, do: "JSON", else: "Instance structs"})"}
          subtitle="The toggle above switches which format is passed to the component — this block follows it"
          code={if @use_json, do: @section_json_pretty, else: inspect(@section_form, pretty: true)}
        />

        <div class="mb-6 flex justify-end">
          <DynamicForm.submit_button form="panels-form-form" class="shadow-lg">
            Save Profile
          </DynamicForm.submit_button>
        </div>

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form
            id="panels-form"
            instance={if !@use_json, do: @section_form}
            json={if @use_json, do: @section_json}
            hide_submit
            submit_text="Save Profile"
          />
        </div>

        <%!-- 3. Create vs edit mode --%>
        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">3. Create vs Edit Mode</h2>
        <p class="text-sm text-gray-500 mb-6">
          The same definition serves both modes. Edit mode prefills the form
          with <code>data={"{...}"}</code>
          (a payload's data round-trips directly), switches the email field to <code>readOnly</code>, and replaces the default
          <code>{"{:dynamic_form, :success, payload}"}</code>
          message with an <code>on_success</code>
          callback sending <code>{"{:contact_updated, data}"}</code>
          instead.
        </p>

        <div class="mb-6 p-4 bg-gray-50 rounded-lg">
          <.form for={%{}} phx-change="change_mode">
            <select
              name="mode"
              class="rounded-md border-gray-300 shadow-sm focus:border-indigo-600 focus:ring-indigo-600"
            >
              <option value="create" selected={@mode == :create}>
                Create mode — empty form, default message on success
              </option>
              <option value="edit" selected={@mode == :edit}>
                Edit mode — prefilled via data map, readOnly email, on_success callback
              </option>
              <option value="edit_struct" selected={@mode == :edit_struct}>
                Edit mode — prefilled via data struct, readOnly email, on_success callback
              </option>
            </select>
          </.form>
        </div>

        <%= if @mode in [:edit, :edit_struct] do %>
          <.definition
            title="Initial Params (edit mode)"
            subtitle="Passed as data={...}; the definition stays the same, with the email field switched to readOnly"
            code={
              inspect(
                if(@mode == :edit_struct, do: sample_edit_struct_data(), else: sample_edit_data()),
                pretty: true
              )
            }
          />
        <% end %>

        <.definition
          title="Form Definition (Instance structs)"
          code={
            inspect((@mode in [:edit, :edit_struct] && @edit_form) || @contact_form, pretty: true)
          }
        />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <%= cond do %>
            <% @mode == :create -> %>
              <DynamicForm.form
                id="contact-create"
                instance={@contact_form}
                on_submit={&Demo.Submissions.verify/1}
                submit_text="Create Contact"
              />
            <% @mode == :edit -> %>
              <DynamicForm.form
                id="contact-edit"
                instance={@edit_form}
                on_submit={&Demo.Submissions.verify/1}
                on_success={fn payload -> send(self(), {:contact_updated, payload.data}) end}
                data={sample_edit_data()}
                submit_text="Update Contact"
              />
            <% @mode == :edit_struct -> %>
              <DynamicForm.form
                id="contact-edit"
                instance={@edit_form}
                on_submit={&Demo.Submissions.verify/1}
                on_success={fn payload -> send(self(), {:contact_updated, payload.data}) end}
                data={sample_edit_struct_data()}
                submit_text="Update Contact"
              />
          <% end %>
        </div>

        <%!-- Submission results --%>
        <div :if={@results != %{}} class="mt-8 rounded-lg bg-green-50 p-6">
          <h3 class="text-lg font-semibold text-green-900 mb-4">Submission Results</h3>
          <div :for={{id, data} <- @results} class="mb-4 text-sm text-green-800">
            <p class="font-semibold">{id}</p>
            <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(data, pretty: true) %></pre>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Sample record for edit mode
  defp sample_edit_data do
    %{
      "name" => "Jane Smith",
      "email" => "jane.smith@example.com",
      "phone" => "(555) 987-6543",
      "preferred_contact" => "email",
      "subject" => "support",
      "message" =>
        "I'm having some issues with the platform and need assistance. The dashboard isn't loading properly.",
      "priority" => "8",
      "subscribe" => "true",
      "newsletter_frequency" => "weekly"
    }
  end

  defp sample_edit_struct_data do
    struct(
      Demo.SampleContact,
      Map.new(sample_edit_data(), fn {k, v} -> {String.to_atom(k), v} end)
    )
  end

  # Edit mode reuses the create definition with the email field locked
  defp disable_email_field(%Instance{} = instance) do
    %{instance | elements: transform_elements(instance.elements)}
  end

  defp transform_elements(elements), do: Enum.map(elements, &transform_element/1)

  defp transform_element(%Instance.Question{name: "email"} = question) do
    %{question | readOnly: true}
  end

  defp transform_element(%Instance.Element{elements: elements} = element)
       when is_list(elements) do
    %{element | elements: transform_elements(elements)}
  end

  defp transform_element(other), do: other
end
