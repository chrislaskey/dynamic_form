defmodule DemoWeb.FormTestLive do
  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  alias DynamicForm.Changeset

  @impl true
  def mount(_params, _session, socket) do
    # Get shared form instance
    form_instance = Demo.FormInstances.contact_form()

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
          <h1 class="text-3xl font-bold text-gray-900">DynamicForm Renderer Test</h1>
          <p class="mt-2 text-gray-600">
            This form is rendered dynamically from a DynamicForm.Instance configuration.
          </p>
        </div>

        <.definition
          title="Form Definition (Instance structs)"
          subtitle={"#{length(DynamicForm.Changeset.get_questions(@form_instance.elements))} questions — submits through Demo.Submissions.create/1"}
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
            submit_text="Submit Form"
            phx_submit="submit"
            phx_change="validate"
            form_id="test-form"
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
        # Submit through the context — the action half of an on_submit callback
        form_data = Ecto.Changeset.apply_changes(changeset)

        case Demo.Submissions.create(form_data) do
          {:ok, result} ->
            {:noreply,
             socket
             |> assign(:submitted_data, form_data)
             |> put_flash(:info, result[:message] || "Form submitted successfully!")}

          {:error, _reason} ->
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
