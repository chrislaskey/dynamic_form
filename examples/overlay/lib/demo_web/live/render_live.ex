defmodule DemoWeb.RenderLive do
  @moduledoc """
  Demo page showcasing DynamicForm in both create and edit modes.

  Features:
  - Mode selector to switch between create and edit
  - Pre-populated data in edit mode
  - Display of submitted values on success
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  alias DynamicForm.Instance

  @impl true
  def mount(_params, _session, socket) do
    create_form = Demo.FormInstances.contact_form()
    edit_form = disable_email_field(create_form)

    {:ok,
     assign(socket,
       create_form: create_form,
       edit_form: edit_form,
       mode: :create,
       last_submission: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Create vs Edit Mode Demo</h1>
          <p class="mt-2 text-gray-600">
            This demo shows how the same form can be used to both create new records and edit existing ones.
          </p>
        </div>
        
    <!-- Mode Selector -->
        <div class="mb-6 p-4 bg-gray-50 rounded-lg">
          <h3 class="font-semibold mb-3 text-gray-900">Test Mode:</h3>
          <.form for={%{}} phx-change="change_mode">
            <select
              name="mode"
              class="rounded-md border-gray-300 shadow-sm focus:border-indigo-600 focus:ring-indigo-600"
            >
              <option value="create" selected={@mode == :create}>
                Create Mode - Empty form for new records
              </option>
              <option value="edit" selected={@mode == :edit}>
                Edit Mode - Pre-populated with existing data
              </option>
            </select>
          </.form>

          <div class="mt-3 p-3 bg-white rounded border border-gray-200">
            <p class="text-sm font-medium text-gray-700">
              Current mode: <code class="text-indigo-600">{@mode}</code>
            </p>
            <%= if @mode == :edit do %>
              <p class="text-sm text-gray-600 mt-2">
                Form is pre-populated with sample data. Some fields (ID, Email) are disabled to prevent changes.
              </p>
            <% else %>
              <p class="text-sm text-gray-600 mt-2">
                Form starts empty, ready to create a new contact record.
              </p>
            <% end %>
          </div>
        </div>

        <%= if @mode == :edit do %>
          <.definition
            title="Initial Params (edit mode)"
            subtitle="Passed as params={...}; the definition below stays the same, with the email field switched to readOnly"
            code={inspect(sample_edit_data(), pretty: true)}
          />
        <% end %>

        <.definition
          title="Form Definition (Instance structs)"
          code={inspect((@mode == :edit && @edit_form) || @create_form, pretty: true)}
        />
        
    <!-- The Form -->
        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <%= if @mode == :create do %>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">{@create_form.title}</h2>
            <%= if @create_form.description do %>
              <p class="text-gray-600 mb-6">{@create_form.description}</p>
            <% end %>

            <.live_component
              module={DynamicForm.RendererLive}
              id="contact-form"
              instance={@create_form}
              on_submit={&Demo.Submissions.verify/1}
              params={%{}}
              submit_text="Create Contact"
            />
          <% end %>

          <%= if @mode == :edit do %>
            <h2 class="text-xl font-semibold text-gray-900 mb-2">{@edit_form.title}</h2>
            <%= if @edit_form.description do %>
              <p class="text-gray-600 mb-6">{@edit_form.description}</p>
            <% end %>

            <.live_component
              module={DynamicForm.RendererLive}
              id="contact-form-edit"
              instance={@edit_form}
              on_submit={&Demo.Submissions.verify/1}
              params={sample_edit_data()}
              submit_text="Update Contact"
            />
          <% end %>
        </div>
        
    <!-- Submission Result Display -->
        <%= if @last_submission do %>
          <div class="mt-8 rounded-lg bg-green-50 p-6">
            <h3 class="text-lg font-semibold text-green-900 mb-4">
              ✓ Form Submitted Successfully!
            </h3>
            <div class="space-y-4">
              <div>
                <p class="text-sm font-semibold text-green-800 mb-2">Mode:</p>
                <div class="bg-green-100 p-3 rounded">
                  <code class="text-sm text-green-900">{@last_submission.mode}</code>
                </div>
              </div>
              <div>
                <p class="text-sm font-semibold text-green-800 mb-2">Submitted Values:</p>
                <div class="bg-green-100 p-4 rounded overflow-x-auto">
                  <pre class="text-xs text-green-900"><%= inspect(@last_submission.data, pretty: true) %></pre>
                </div>
              </div>
            </div>
          </div>
        <% end %>
        
    <!-- Documentation -->
        <div class="mt-8 rounded-lg bg-gray-50 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">How It Works</h3>
          <div class="space-y-3 text-sm text-gray-700">
            <div>
              <h4 class="font-semibold">Create Mode</h4>
              <p class="mt-1">
                The form is initialized with empty params:
                <code class="bg-white px-2 py-1 rounded">params={inspect(%{})}</code>
              </p>
            </div>
            <div>
              <h4 class="font-semibold">Edit Mode</h4>
              <p class="mt-1">
                The form is initialized with existing data:
                <code class="bg-white px-2 py-1 rounded">
                  params={inspect(%{"name" => "...", "email" => "..."})}
                </code>
              </p>
              <p class="mt-1 text-xs text-gray-600">
                The same DynamicForm.RendererLive component handles both cases automatically.
                In edit mode, certain fields (like ID and Email) are marked as
                <code class="bg-white px-1 rounded">readOnly: true</code>
                to prevent modification while still displaying the values.
              </p>
            </div>
            <div>
              <h4 class="font-semibold">Implementation</h4>
              <p class="mt-1">
                Both modes use the same
                <code class="bg-white px-2 py-1 rounded">DynamicForm.RendererLive</code>
                component,
                just with different <code class="bg-white px-2 py-1 rounded">:params</code>
                values. The component
                automatically handles the changeset creation and validation.
              </p>
              <p class="mt-1 text-xs text-gray-600">
                Valid submissions arrive as
                <code class="bg-white px-1 rounded">&lbrace;:dynamic_form, payload&rbrace;</code>
                messages via <code class="bg-white px-1 rounded">handle_info/2</code>,
                allowing the parent LiveView to update state and display the submitted data.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Handle the valid-submission message from the form component — this is
  # where the side effect happens. Invalid submissions render inline only.
  @impl true
  def handle_info({:dynamic_form, %DynamicForm.Payload{data: data}}, socket) do
    {:ok, result} = Demo.Submissions.create(data)

    {:noreply,
     socket
     |> put_flash(:info, "✓ #{result.message}")
     |> assign(:last_submission, %{
       mode: socket.assigns.mode,
       data: data,
       timestamp: DateTime.utc_now()
     })}
  end

  # Handle mode changes
  @impl true
  def handle_event("change_mode", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(:mode, String.to_atom(mode))
     |> assign(:last_submission, nil)}
  end

  # Sample data for edit mode
  defp sample_edit_data do
    %{
      "id" => "bc7a4a1f-0a04-4846-939f-6156e12ccf06",
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

  # Transform function to add readOnly: true to the email field
  defp disable_email_field(%Instance{} = instance) do
    %{instance | elements: transform_elements(instance.elements)}
  end

  # Transform elements list, handling both Questions and Elements
  defp transform_elements(elements) when is_list(elements) do
    Enum.map(elements, &transform_element/1)
  end

  # Transform a single Question - add readOnly: true if it's the email field
  defp transform_element(%Instance.Question{name: "email"} = question) do
    %{question | readOnly: true}
  end

  # Transform a single Question - leave other questions unchanged
  defp transform_element(%Instance.Question{} = question) do
    question
  end

  # Transform an Element - recursively transform nested elements if they exist
  defp transform_element(%Instance.Element{elements: elements} = element)
       when is_list(elements) do
    %{element | elements: transform_elements(elements)}
  end

  # Transform an Element without nested elements - leave unchanged
  defp transform_element(%Instance.Element{} = element) do
    element
  end
end
