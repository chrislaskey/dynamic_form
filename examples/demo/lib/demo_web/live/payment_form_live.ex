defmodule DemoWeb.PaymentFormLive do
  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  alias DynamicForm.Changeset

  @impl true
  def mount(_params, _session, socket) do
    # Get payment form instance
    form_instance = Demo.FormInstances.payment_form()

    # Create initial changeset
    changeset = Changeset.create_changeset(form_instance, %{})
    form = to_form(changeset, as: "form")

    {:ok,
     socket
     |> assign(:form_instance, form_instance)
     |> assign(:changeset, changeset)
     |> assign(:form, form)
     |> assign(:submitted_data, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Payment Form - Conditional Visibility Demo</h1>
          <p class="mt-2 text-gray-600">
            This form demonstrates conditional field visibility. Select different payment methods to see how the form dynamically shows and hides relevant fields.
          </p>
        </div>

        <.definition
          title="Form Definition (Instance structs)"
          subtitle={"#{length(DynamicForm.Changeset.get_questions(@form_instance.elements))} questions, #{Enum.count(DynamicForm.Changeset.get_questions(@form_instance.elements), &(&1.visibleIf != nil))} conditional (visibleIf) — submits through Demo.Submissions.create/1"}
          code={inspect(@form_instance, pretty: true)}
        />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <h2 class="text-xl font-semibold text-gray-900 mb-6">{@form_instance.title}</h2>
          <%= if @form_instance.description do %>
            <p class="text-gray-600 mb-6">{@form_instance.description}</p>
          <% end %>

          <DynamicForm.Renderer.render
            instance={@form_instance}
            form={@form}
            submit_text="Process Payment"
            phx_submit="submit"
            phx_change="validate"
            form_id="payment-form"
          />
        </div>

        <%= if @submitted_data do %>
          <div class="mt-8 rounded-lg bg-green-50 p-6">
            <h3 class="text-lg font-semibold text-green-900 mb-4">
              ✓ Payment Submitted Successfully!
            </h3>
            <div class="text-sm text-green-800">
              <p class="font-semibold mb-2">Submitted Data:</p>
              <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(@submitted_data, pretty: true) %></pre>
            </div>
          </div>
        <% end %>

        <div class="mt-8 rounded-lg bg-blue-50 p-6">
          <h3 class="text-lg font-semibold text-blue-900 mb-4">💡 How It Works</h3>
          <div class="text-sm text-blue-800 space-y-2">
            <p>
              <strong>Try it:</strong>
              Change the "Payment Method" dropdown to see different fields appear:
            </p>
            <ul class="list-disc list-inside ml-4 space-y-1">
              <li><strong>Credit Card</strong> - Shows card number, expiry date, and CVV fields</li>
              <li><strong>Bank Transfer</strong> - Shows account number and routing number fields</li>
              <li><strong>PayPal</strong> - Shows PayPal email field</li>
            </ul>
            <p class="mt-4">
              Each conditional field has a <code class="bg-blue-100 px-1 rounded">visibleIf</code>
              expression that checks the payment method value, e.g. <code class="bg-blue-100 px-1 rounded">&lbrace;payment_method&rbrace; = 'credit_card'</code>.
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    changeset =
      socket.assigns.form_instance
      |> Changeset.create_changeset(params)
      |> Map.put(:action, :validate)

    form = to_form(changeset, as: "form")

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    changeset =
      socket.assigns.form_instance
      |> Changeset.create_changeset(params)
      |> Map.put(:action, :update)

    case changeset.valid? do
      true ->
        # Submit through the context, the same function on_valid_submit takes
        form_data = Ecto.Changeset.apply_changes(changeset)

        case Demo.Submissions.create(form_data) do
          {:ok, result} ->
            {:noreply,
             socket
             |> assign(:submitted_data, form_data)
             |> put_flash(:info, result[:message] || "Payment submitted successfully!")}

          {:error, _reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to submit payment")}
        end

      false ->
        changeset = Map.put(changeset, :action, :validate)
        form = to_form(changeset, as: "form")

        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, form)
         |> put_flash(:error, "Please fix the errors below")}
    end
  end
end
