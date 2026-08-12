defmodule DemoWeb.ContactFormComponent do
  @moduledoc """
  A LiveComponent that hosts a DynamicForm and reacts to successful
  submissions by updating its own state.

  Demonstrates the `on_success` + `send_update/2` pattern: since
  LiveComponents don't have `handle_info/2`, the default
  `{:dynamic_form, payload}` message won't reach them. Instead,
  `on_success` calls `Phoenix.LiveView.send_update/2` to trigger
  this component's `update/2` with the submission data.
  """

  use DemoWeb, :live_component

  @impl true
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div :if={@submission_count > 0} class="rounded-lg bg-green-50 border border-green-200 p-4">
        <div class="flex items-center gap-4">
          <div class="text-sm text-green-800">
            Submissions handled by this component:
            <span class="font-semibold">{@submission_count}</span>
          </div>
          <div :if={@last_submission} class="text-sm text-green-600">
            Last: <span class="font-medium">{Map.get(@last_submission, :name, "—")}</span>
            (<span class="font-medium">{Map.get(@last_submission, :email, "—")}</span>)
          </div>
        </div>
      </div>

      <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
        <DynamicForm.form
          id={"#{@id}-form"}
          on_submit={&Demo.Submissions.verify/1}
          on_success={&handle_form_success(&1, @id)}
          submit_text="Submit from Component"
        >
          <:field type="text" name="name" label="Name" required min_length={2} />
          <:field
            type="text"
            name="email"
            label="Email"
            input_type="email"
            required
            format="email"
          />
          <:field
            type="dropdown"
            name="subject"
            label="Subject"
            required
            options={[{"Support", "support"}, {"Sales", "sales"}, {"Other", "other"}]}
          />
          <:field type="comment" name="message" label="Message" required min_length={10} />
        </DynamicForm.form>
      </div>
    </div>
    """
  end

  defp handle_form_success(payload, component_id) do
    Phoenix.LiveView.send_update(DemoWeb.ContactFormComponent, %{
      id: component_id,
      event: "form_success",
      payload: payload
    })
  end
end
