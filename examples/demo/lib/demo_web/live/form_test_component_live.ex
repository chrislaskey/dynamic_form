defmodule DemoWeb.FormTestComponentLive do
  @moduledoc """
  Test page for the DynamicForm.RendererLive LiveComponent.

  This demonstrates the two success-handling patterns:
  - Default: the component messages the parent with {:dynamic_form, payload}
  - Custom: an on_success callback replaces the default message
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  @impl true
  def mount(_params, _session, socket) do
    form_instance = Demo.FormInstances.contact_form()

    {:ok,
     assign(socket,
       form_instance: form_instance,
       callback_mode: :message,
       last_result: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">LiveComponent Renderer Test</h1>
          <p class="mt-2 text-gray-600">
            This form uses the
            <code class="bg-gray-100 px-2 py-1 rounded">DynamicForm.RendererLive</code>
            LiveComponent with automatic state management.
          </p>
          <p class="mt-2 text-sm text-indigo-600">
            <strong>New:</strong>
            This form uses an external submit button (shown below) instead of a button inside the form.
          </p>
        </div>

        <.definition
          title="Form Definition (Instance structs)"
          subtitle="The shared contact form instance, rendered by DynamicForm.RendererLive below"
          code={inspect(@form_instance, pretty: true)}
        />
        
    <!-- Mode Selector -->
        <div class="mb-6 p-4 bg-gray-50 rounded-lg">
          <h3 class="font-semibold mb-3 text-gray-900">Usage Mode:</h3>
          <p class="text-sm text-gray-600 mb-3">
            Switch between different usage patterns to see how the component behaves.
          </p>
          <.form for={%{}} phx-change="change_mode">
            <select
              name="mode"
              class="rounded-md border-gray-300 shadow-sm focus:border-indigo-600 focus:ring-indigo-600"
            >
              <option value="message" selected={@callback_mode == :message}>
                Default Message Passing
              </option>
              <option value="custom" selected={@callback_mode == :custom}>
                Custom on_success Callback
              </option>
            </select>
          </.form>

          <div class="mt-3 text-sm">
            <p class="font-medium text-gray-700">Current mode:</p>
            <code class="block mt-1 bg-white p-2 rounded">{describe_mode(@callback_mode)}</code>
          </div>
        </div>

        <%!-- External submit button at the top --%>
        <div class="mb-6 flex justify-end">
          <DynamicForm.submit_button form="contact-form-form" class="shadow-lg">
            {if @callback_mode == :message,
              do: "💾 Submit (Default Message)",
              else: "💾 Submit (Custom on_success)"}
          </DynamicForm.submit_button>
        </div>
        
    <!-- LiveComponent with dynamic modes -->
        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <%= if @callback_mode == :message do %>
            <.live_component
              module={DynamicForm.RendererLive}
              id="contact-form"
              instance={@form_instance}
              on_submit={&Demo.Submissions.verify/1}
              hide_submit={true}
              submit_text="Submit (Default Message)"
            />
          <% end %>

          <%= if @callback_mode == :custom do %>
            <.live_component
              module={DynamicForm.RendererLive}
              id="contact-form"
              instance={@form_instance}
              on_submit={&Demo.Submissions.verify/1}
              on_success={fn payload -> send(self(), {:custom_success, payload.data}) end}
              hide_submit={true}
              submit_text="Submit (Custom on_success)"
            />
          <% end %>
        </div>

        <%= if @last_result do %>
          <div class="mt-8 rounded-lg bg-green-50 p-6">
            <h3 class="text-lg font-semibold text-green-900 mb-4">Last Submission Result</h3>
            <div class="text-sm text-green-800">
              <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(@last_result, pretty: true) %></pre>
            </div>
          </div>
        <% end %>
        
    <!-- Documentation -->
        <div class="mt-8 rounded-lg bg-gray-50 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">About Usage Patterns</h3>
          <div class="space-y-4 text-sm text-gray-700">
            <div>
              <h4 class="font-semibold">Default Message Passing</h4>
              <p class="mt-1">
                By default the component sends a message shaped like
                <code class="bg-white px-1 rounded">
                  &lbrace;:dynamic_form, %DynamicForm.Payload&lbrace;&rbrace;&rbrace;
                </code>
                to the parent LiveView via <code class="bg-white px-1 rounded">handle_info/2</code>
                on every <em>valid</em>
                submission — invalid ones render their errors
                inline on the form. This is where the parent performs the side effect:
                insert a record, show a flash message, navigate, etc.
              </p>
            </div>
            <div>
              <h4 class="font-semibold">Custom on_success Callback</h4>
              <p class="mt-1">
                Defining <code class="bg-white px-1 rounded">on_success</code>
                replaces the default message: the function is called with the payload on
                every valid submission instead. Use it to send a differently-shaped message
                (this page sends <code class="bg-white px-1 rounded">&lbrace;:custom_success, data&rbrace;</code>),
                broadcast over PubSub, or make the form fully self-contained.
              </p>
            </div>
            <div>
              <h4 class="font-semibold">✨ External Submit Button</h4>
              <p class="mt-1">
                This form demonstrates the external submit button feature. The submit button
                at the top uses <code class="bg-white px-1 rounded">form="contact-form-form"</code>
                to connect to the LiveComponent. Note: the form ID is auto-generated as <code class="bg-white px-1 rounded">"&#123;id&#125;-form"</code>, so component ID
                "contact-form" becomes form ID "contact-form-form".
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Default mode: valid submissions arrive as {:dynamic_form, payload} and
  # the side effect (create) runs in the parent
  @impl true
  def handle_info({:dynamic_form, %DynamicForm.Payload{data: data}}, socket) do
    {:ok, result} = Demo.Submissions.create(data)

    {:noreply,
     socket
     |> put_flash(:info, "✓ #{result.message}")
     |> assign(:last_result, result)}
  end

  # Custom mode: the on_success callback sent this instead of the default
  @impl true
  def handle_info({:custom_success, data}, socket) do
    {:ok, result} = Demo.Submissions.create(data)

    {:noreply,
     socket
     |> put_flash(:info, "✓ Custom on_success: #{result.message}")
     |> assign(:last_result, result)}
  end

  # Mode switcher
  @impl true
  def handle_event("change_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :callback_mode, String.to_existing_atom(mode))}
  end

  defp describe_mode(:message) do
    """
    (no attributes — the default)
    """
  end

  defp describe_mode(:custom) do
    """
    on_success={fn payload -> send(self(), {:custom_success, payload.data}) end}
    """
  end
end
