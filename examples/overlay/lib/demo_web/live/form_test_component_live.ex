defmodule DemoWeb.FormTestComponentLive do
  @moduledoc """
  Test page for the DynamicForm.RendererLive LiveComponent.

  This demonstrates the two usage patterns:
  - Message passing (send_messages: true)
  - No messages (self-contained)
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
                Message Passing (send_messages: true)
              </option>
              <option value="none" selected={@callback_mode == :none}>
                No Messages (self-contained)
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
              do: "💾 Submit with Messages",
              else: "💾 Submit (No Messages)"}
          </DynamicForm.submit_button>
        </div>
        
    <!-- LiveComponent with dynamic modes -->
        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <%= if @callback_mode == :message do %>
            <.live_component
              module={DynamicForm.RendererLive}
              id="contact-form"
              instance={@form_instance}
              send_messages={true}
              hide_submit={true}
              submit_text="Submit with Messages"
            />
          <% end %>

          <%= if @callback_mode == :none do %>
            <.live_component
              module={DynamicForm.RendererLive}
              id="contact-form"
              instance={@form_instance}
              hide_submit={true}
              submit_text="Submit (No Messages)"
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
              <h4 class="font-semibold">Message Passing</h4>
              <p class="mt-1">
                Sends a submit-outcome message shaped like
                <code class="bg-white px-1 rounded">
                  &lbrace;:dynamic_form_submit, id, &lbrace;:ok, payload&rbrace;&rbrace;
                </code>
                or
                <code class="bg-white px-1 rounded">
                  &lbrace;:dynamic_form_submit, id, &lbrace;:error, payload&rbrace;&rbrace;
                </code>
                to the parent LiveView via <code class="bg-white px-1 rounded">handle_info/2</code>.
                This allows the parent LiveView to update state, show flash messages, navigate, etc.
              </p>
            </div>
            <div>
              <h4 class="font-semibold">No Messages</h4>
              <p class="mt-1">
                The component handles everything internally. Useful for simple forms that don't
                need custom behavior after submission. The form will still validate and submit,
                but the parent LiveView won't be notified of the results.
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

  # Message handlers
  @impl true
  def handle_info({:dynamic_form_submit, _id, {:ok, %{result: result}}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "✓ #{result.message}")
     |> assign(:last_result, result)}
  end

  @impl true
  def handle_info({:dynamic_form_submit, _id, {:error, _payload}}, socket) do
    {:noreply, put_flash(socket, :error, "✗ Please fix the errors below")}
  end

  # Mode switcher
  @impl true
  def handle_event("change_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :callback_mode, String.to_atom(mode))}
  end

  defp describe_mode(:message) do
    """
    send_messages={true}
    """
  end

  defp describe_mode(:none) do
    """
    (no message attributes)
    """
  end
end
