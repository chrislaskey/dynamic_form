# Lifecycle Events

How a form moves through its lifecycle, and how the parent LiveView is
notified. For the submission contract itself see
[Usage: Backends](usage.md#backends).

## Notifying the parent: `send_messages`

With `send_messages` attribute, the component sends the parent LiveView a message on
every submission, carrying the outcome as an idiomatic ok/error tuple:

```elixir
{:dynamic_form_submit, component_id, {:ok, payload}}
{:dynamic_form_submit, component_id, {:error, payload}}
```

- `component_id` — the form's `id`, for routing when a page renders several
  forms.
- The outcome tuple mirrors Elixir convention (`Repo.insert/2` returns
  `{:ok, struct} | {:error, changeset}` for the same situation); payloads are
  maps, per outcome below.

A complete LiveView:

```elixir
defmodule MyAppWeb.ContactLive do
  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <DynamicForm.form id="contact-form" send_messages>
        <:field type="text" name="name" label="Name" required />
        <:field type="text" name="email" input_type="email" label="Email Address"
                required format="email" />
        <:field type="comment" name="message" label="Message" required />
      </DynamicForm.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_info({:dynamic_form_submit, _id, {:ok, %{result: result}}}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, result[:message])
     |> push_navigate(to: ~p"/thank-you")}
  end

  def handle_info({:dynamic_form_submit, _id, {:error, %{changeset: changeset}}}, socket) do
    Logger.warning("Contact form rejected: #{inspect(changeset.errors)}")
    {:noreply, put_flash(socket, :error, gettext("Please fix the errors below")}
  end
end
```

Handlers can also take both outcomes in one head and branch on the tuple:

```elixir
def handle_info({:dynamic_form_submit, id, outcome}, socket) do
  case outcome do
    {:ok, payload} -> track_submission(id, payload)
    {:error, payload} -> track_rejection(id, payload)
  end

  {:noreply, socket}
end
```

Without `send_messages`, the component is fully self-contained: it validates,
submits, and renders errors, and the parent is never notified.

## Outcomes and payloads

| Outcome | When | Payload |
|---|---|---|
| `{:ok, %{result: result, data: data}}` | Backend returned `{:cont, result}`, or no backend and the changeset was valid | `result` is the backend's map (typically `:message`/`:data`), or `%{}` without a backend; `data` is the applied changeset data |
| `{:error, %{changeset: changeset, reason: reason}}` | Backend returned `{:halt, _}`, or no backend and the changeset was invalid | `changeset` carries the errors rendered inline; `reason` is a backend's non-changeset `{:halt, reason}` term, or `nil` |

Validation (`phx-change`) does not notify the parent — inline errors and
conditional logic are handled inside the component.

## Architecture

`DynamicForm.form/1` (via `DynamicForm.RendererLive`) owns the full cycle
internally:

```
user types ──▶ phx-change ──▶ changeset rebuilt, conditional logic re-evaluated
                              (inline errors display once the form has been submitted)

user submits ─▶ phx-submit ─▶ changeset rebuilt
                    │
                    ├─ backend configured ──▶ backend function called
                    │      {:cont, result}           ──▶ {:ok, payload}
                    │      {:halt, changeset/reason} ──▶ {:error, payload}, errors rendered inline
                    │
                    └─ no backend ──▶ valid changeset ──▶ {:ok, payload}
                                      invalid          ──▶ {:error, payload}, errors rendered inline
```

Validation runs on every change and every submit — the component handles it
without involving the parent LiveView. The parent hears about submissions
when `send_messages` is enabled.
