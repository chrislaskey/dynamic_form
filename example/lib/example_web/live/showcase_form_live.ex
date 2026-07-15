defmodule ExampleWeb.ShowcaseFormLive do
  use ExampleWeb, :live_view

  alias DynamicForm.{Changeset, Instance}

  @impl true
  def mount(_params, _session, socket) do
    # Get showcase form instance (could be struct, JSON, or map)
    form_instance_raw = Example.FormInstances.showcase_form()

    # Decode at the edge - ensure we have an Instance struct
    form_instance = decode_instance(form_instance_raw)

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

  # Decode instance at the edge of the system
  defp decode_instance(data) when is_binary(data) or is_map(data) do
    Instance.decode!(data)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">DynamicForm Feature Showcase</h1>
        <p class="mt-2 text-gray-600">
          This comprehensive example demonstrates all the capabilities of the DynamicForm library.
        </p>
      </div>

      <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
        <DynamicForm.Renderer.render
          instance={@form_instance}
          form={@form}
          submit_text="Submit Showcase Form"
          phx_submit="submit"
          phx_change="validate"
          form_id="showcase-form"
        />
      </div>

      <%= if @submitted_data do %>
        <div class="mt-8 rounded-lg bg-green-50 p-6">
          <h3 class="text-lg font-semibold text-green-900 mb-4">✓ Form Submitted Successfully!</h3>
          <div class="text-sm text-green-800">
            <p class="font-semibold mb-2">Submitted Data:</p>
            <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(@submitted_data, pretty: true) %></pre>
          </div>
        </div>
      <% end %>

      <div class="mt-8 rounded-lg bg-blue-50 p-6">
        <h3 class="text-lg font-semibold text-blue-900 mb-4">💡 Features Demonstrated</h3>
        <div class="text-sm text-blue-800 space-y-3">
          <div>
            <strong>Elements:</strong>
            <ul class="list-disc list-inside ml-4 mt-1">
              <li>Headings with different levels (h2, h3)</li>
              <li>Paragraphs with custom styling</li>
              <li>Dividers for visual separation</li>
            </ul>
          </div>

          <div>
            <strong>Groups:</strong>
            <ul class="list-disc list-inside ml-4 mt-1">
              <li>Grid-2 layout for name fields</li>
              <li>Grid-3 layout for city/state/zip</li>
              <li>Horizontal layout for email preferences</li>
              <li>Nested groups (address with city/state/zip group inside)</li>
            </ul>
          </div>

          <div>
            <strong>Conditional Visibility:</strong>
            <ul class="list-disc list-inside ml-4 mt-1">
              <li>Email preferences group appears when email is valid</li>
              <li>Thank you message appears when comments are valid</li>
            </ul>
          </div>

          <div>
            <strong>Field Types:</strong>
            <ul class="list-disc list-inside ml-4 mt-1">
              <li>String, Email, Select, Textarea, Decimal, Boolean</li>
            </ul>
          </div>

          <div>
            <strong>Validations:</strong>
            <ul class="list-disc list-inside ml-4 mt-1">
              <li>Required fields, min/max length, email format, numeric ranges</li>
            </ul>
          </div>
        </div>
      </div>

      <div class="mt-8 rounded-lg bg-gray-50 p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Form Configuration</h3>
        <div class="text-sm text-gray-800">
          <p class="mb-2">
            <span class="font-semibold">Total elements:</span>
            {length(@form_instance.elements)}
          </p>
          <p class="mb-2">
            <span class="font-semibold">Non-question elements:</span>
            {Enum.count(@form_instance.elements, fn element ->
              match?(%DynamicForm.Instance.Element{}, element)
            end)}
          </p>
          <p class="mb-2">
            <span class="font-semibold">Questions (including nested):</span>
            {length(DynamicForm.Changeset.get_questions(@form_instance.elements))}
          </p>
          <details class="mt-4">
            <summary class="cursor-pointer font-semibold text-gray-700 hover:text-gray-900">
              View Full Configuration
            </summary>
            <pre class="mt-2 bg-gray-100 p-4 rounded overflow-x-auto text-xs"><%= inspect(@form_instance, pretty: true) %></pre>
          </details>
        </div>
      </div>
    </div>
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
        # Submit via backend
        instance = socket.assigns.form_instance
        backend_module = instance.backend.module
        backend_function = instance.backend.function
        backend_config = instance.backend.config
        form_data = Ecto.Changeset.apply_changes(changeset)

        case apply(backend_module, backend_function, [form_data, changeset, backend_config]) do
          {:cont, result} ->
            {:noreply,
             socket
             |> assign(:submitted_data, form_data)
             |> put_flash(:info, result[:message] || "Form submitted successfully!")}

          {:halt, _error} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to submit form")}
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
