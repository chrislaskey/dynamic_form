# Lifecycle Events

How a form moves through its lifecycle, and how the parent LiveView is
notified. For the `on_change`/`on_submit` callback contracts see
[Usage: Lifecycle callbacks](usage.md#lifecycle-callbacks-on_change-and-on_submit).

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
| `{:ok, %{result: result, data: data}}` | `on_submit` returned `{:ok, result}`, or no callback and the changeset was valid | `result` is the callback's return value (typically `:message`/`:data`), or `%{}` without a callback; `data` is the applied changeset data |
| `{:error, %{changeset: changeset, reason: reason}}` | The changeset was invalid, or `on_submit` returned `{:error, _}` | `changeset` carries the errors rendered inline; `reason` is an `on_submit` `{:error, reason}` term, or `nil` |

Validation (`phx-change`) does not notify the parent — inline errors and
conditional logic are handled inside the component.

## Architecture

`DynamicForm.form/1` (via `DynamicForm.RendererLive`) owns the full cycle
internally:

```
user types ──▶ phx-change ──▶ built-in validations ──▶ on_change(changeset, data)
                              conditional logic re-evaluated
                              (inline errors display once the form has been submitted)

user submits ─▶ phx-submit ─▶ built-in validations ──▶ on_change(changeset, data)
                    │
                    ├─ on_submit given ──▶ on_submit(changeset, data)   [valid or not]
                    │      {:ok, result}       ──▶ {:ok, payload}
                    │      {:error, changeset} ──▶ {:error, payload}, errors rendered inline
                    │      {:error, reason}    ──▶ {:error, payload}
                    │
                    └─ no on_submit ──▶ valid   ──▶ {:ok, payload} with the form data
                                        invalid ──▶ {:error, payload}, errors rendered inline
```

Validation runs on every change and every submit — the component handles it
without involving the parent LiveView. `on_change` and `on_submit` extend
the cycle from the application side (see
[Usage: Lifecycle callbacks](usage.md#lifecycle-callbacks-on_change-and-on_submit));
the parent hears about submissions when `send_messages` is enabled.
