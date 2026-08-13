defmodule DemoWeb.ComponentFormLive do
  @moduledoc """
  Demonstrates using DynamicForm inside a LiveComponent.

  The form lives in `DemoWeb.ContactFormComponent`, which uses `on_success`
  with `Phoenix.LiveView.send_update/2` to handle submissions within its own
  lifecycle — no `handle_info/2` needed in the parent LiveView.
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  @src_component ~S"""
  defmodule DemoWeb.ContactFormComponent do
    use DemoWeb, :live_component

    def update(%{event: "form_success", payload: payload}, socket) do
      {:ok, _result} = Demo.Submissions.create(payload.data)

      {:ok,
       socket
       |> assign(:submission_count, socket.assigns.submission_count + 1)
       |> assign(:last_submission, payload.data)}
    end

    def update(assigns, socket) do
      {:ok,
       socket
       |> assign(assigns)
       |> assign_new(:submission_count, fn -> 0 end)
       |> assign_new(:last_submission, fn -> nil end)}
    end

    def render(assigns) do
      ~H\"""
      <div>
        <DynamicForm.form
          id={"#{@id}-form"}
          on_submit={&Demo.Submissions.verify/1}
          on_success={&handle_form_success(&1, @id)}
          submit_text="Submit from Component"
        >
          <:field type="text" name="name" label="Name" required />
          <:field type="text" name="email" label="Email" format="email" required />
        </DynamicForm.form>
      </div>
      \"""
    end

    defp handle_form_success(payload, component_id) do
      Phoenix.LiveView.send_update(DemoWeb.ContactFormComponent, %{
        id: component_id,
        event: "form_success",
        payload: payload
      })
    end
  end
  """

  @src_usage ~S"""
  <.live_component
    module={DemoWeb.ContactFormComponent}
    id="contact-form-component"
  />
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       src_component: @src_component,
       src_usage: @src_usage
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">LiveComponent Example</h1>
          <p class="mt-2 text-gray-600">
            DynamicForm used inside a LiveComponent. Since LiveComponents don't have
            <code class="bg-gray-100 px-2 py-1 rounded">handle_info/2</code>, the default
            <code class="bg-gray-100 px-2 py-1 rounded">{"{:dynamic_form, :success, payload}"}</code>
            message can't reach them. Instead, pass an
            <code class="bg-gray-100 px-2 py-1 rounded">on_success</code>
            callback that calls
            <code class="bg-gray-100 px-2 py-1 rounded">Phoenix.LiveView.send_update/2</code>
            to notify the component via its own
            <code class="bg-gray-100 px-2 py-1 rounded">update/2</code>
            callback.
          </p>
        </div>

        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-1">How It Works</h2>
        <p class="text-sm text-gray-500 mb-6">
          The LiveComponent defines a private
          <code class="bg-gray-100 px-1 py-0.5 rounded text-xs">handle_form_success/2</code>
          function that captures the component's <code class="bg-gray-100 px-1 py-0.5 rounded text-xs">@id</code>
          and calls <code class="bg-gray-100 px-1 py-0.5 rounded text-xs">send_update/2</code>.
          After a valid submission, the component's
          <code class="bg-gray-100 px-1 py-0.5 rounded text-xs">update/2</code>
          pattern-matches on the event and updates its own assigns — no parent LiveView involvement needed.
        </p>

        <div class="mb-6 rounded-lg bg-indigo-50 border border-indigo-200 p-4">
          <h3 class="text-sm font-semibold text-indigo-900 mb-2">Key Insight</h3>
          <p class="text-sm text-indigo-700">
            <code class="bg-indigo-100 px-1 py-0.5 rounded text-xs">on_success</code>
            is called synchronously inside
            <code class="bg-indigo-100 px-1 py-0.5 rounded text-xs">RendererLive.handle_event("submit", ...)</code>.
            Since all LiveComponents share their parent LiveView's process,
            <code class="bg-indigo-100 px-1 py-0.5 rounded text-xs">send_update/2</code>
            targets the right process automatically.
          </p>
        </div>

        <.definition
          title="LiveComponent Definition"
          subtitle="The on_success callback uses send_update to route the payload back to the component"
          code={@src_component}
        />

        <.definition
          title="Usage in Parent LiveView"
          subtitle="The parent only mounts the component — no handle_info needed"
          code={@src_usage}
        />

        <h2 class="mt-12 text-xl font-semibold text-gray-900 mb-4">Live Demo</h2>
        <p class="text-sm text-gray-500 mb-6">
          Submit the form below — the success counter and last submission update
          entirely within the LiveComponent's own state. Try
          <code class="bg-gray-100 px-1 py-0.5 rounded text-xs">taken@example.com</code>
          to see the on_submit validation error.
        </p>

        <.live_component module={DemoWeb.ContactFormComponent} id="contact-form-component" />
      </div>
    </Layouts.app>
    """
  end
end
