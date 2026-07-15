defmodule ExampleWeb.SurveyjsTestLive do
  use ExampleWeb, :live_view

  @moduledoc """
  LiveView for testing SurveyJS-format form definitions.

  This page loads forms from JSON files and renders them using the
  DynamicForm.RendererLive component.
  """

  @impl true
  def mount(_params, _session, socket) do
    # Load the test form from JSON
    form_path = Path.join(:code.priv_dir(:example), "surveyjs_test_form.json")
    payment_form_path = Path.join(:code.priv_dir(:example), "surveyjs_payment_form.json")

    test_form = load_form(form_path)
    payment_form = load_form(payment_form_path)

    {:ok,
     assign(socket,
       test_form: test_form,
       payment_form: payment_form,
       active_form: :test,
       success_message: nil
     )}
  end

  defp load_form(path) do
    case File.read(path) do
      {:ok, json} ->
        DynamicForm.Instance.decode!(json)

      {:error, reason} ->
        raise "Failed to load form from #{path}: #{inspect(reason)}"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto py-8 px-4">
      <h1 class="text-3xl font-bold text-gray-900 mb-6">SurveyJS Format Test</h1>

      <div class="mb-6">
        <div class="flex space-x-4">
          <button
            type="button"
            phx-click="switch_form"
            phx-value-form="test"
            class={"px-4 py-2 rounded-md #{if @active_form == :test, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
          >
            Contact Form
          </button>
          <button
            type="button"
            phx-click="switch_form"
            phx-value-form="payment"
            class={"px-4 py-2 rounded-md #{if @active_form == :payment, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
          >
            Payment Form
          </button>
        </div>
      </div>

      <%= if @success_message do %>
        <div class="rounded-md bg-green-50 p-4 mb-6">
          <div class="flex">
            <div class="flex-shrink-0">
              <svg
                class="h-5 w-5 text-green-400"
                viewBox="0 0 20 20"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <div class="ml-3">
              <p class="text-sm font-medium text-green-800">{@success_message}</p>
            </div>
          </div>
        </div>
      <% end %>

      <div class="bg-white shadow rounded-lg p-6">
        <%= if @active_form == :test do %>
          <.live_component
            module={DynamicForm.RendererLive}
            id="surveyjs-test-form"
            instance={@test_form}
            send_messages={true}
            submit_text="Submit Contact Form"
            validation_summary="detailed"
          />
        <% else %>
          <.live_component
            module={DynamicForm.RendererLive}
            id="surveyjs-payment-form"
            instance={@payment_form}
            send_messages={true}
            submit_text="Process Payment"
            validation_summary="detailed"
          />
        <% end %>
      </div>

      <div class="mt-8 p-4 bg-gray-50 rounded-lg">
        <h2 class="text-lg font-semibold text-gray-900 mb-2">Form Configuration (JSON)</h2>
        <pre class="text-xs bg-gray-800 text-green-400 p-4 rounded overflow-auto max-h-96"><%= Jason.encode!(active_instance(@active_form, @test_form, @payment_form), pretty: true) %></pre>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("switch_form", %{"form" => form}, socket) do
    active_form = String.to_existing_atom(form)
    {:noreply, assign(socket, active_form: active_form, success_message: nil)}
  end

  @impl true
  def handle_info({:dynamic_form_success, _id, result}, socket) do
    message = Map.get(result, :message, "Form submitted successfully!")
    {:noreply, assign(socket, success_message: message)}
  end

  defp active_instance(:test, test_form, _payment_form), do: test_form
  defp active_instance(:payment, _test_form, payment_form), do: payment_form
end
