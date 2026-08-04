defmodule DemoWeb.FormTestLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  # The stateless DynamicForm.Renderer emits phx-change/phx-submit without a
  # phx-target, so LiveView dispatches the events to the *parent* LiveView's
  # handle_event/3 — no LiveComponent involved in state management.
  test "form events without phx-target are handled by the parent LiveView", %{conn: conn} do
    {:ok, view, html} = live(conn, "/form-test")

    refute html =~ "Please fix the errors below"

    # The parent's handle_event("submit", ...) runs and flashes on the
    # invalid changeset
    view
    |> form("#test-form", %{"form" => %{"name" => "x"}})
    |> render_submit()

    assert render(view) =~ "Please fix the errors below"
  end
end
