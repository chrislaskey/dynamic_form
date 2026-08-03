defmodule ExampleWeb.SlotFormLiveTest do
  use ExampleWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders all slot-defined forms", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/slot-forms")

    # Basic form fields
    assert html =~ "Email Address"
    assert html =~ "Subject"
    assert html =~ "Satisfaction"

    # visible_if fields start hidden
    refute html =~ "Support Details"
    refute html =~ "Shipping Address"

    # Custom markup tiers
    assert html =~ "Welcome to Acme Corp"
    assert html =~ ~s(type="range")
    assert html =~ "Live summary (fully custom element)"

    # Data mode through the same entry point
    assert html =~ ~s(id="data-mode-form-form")
  end

  test "visible_if reveals dependent fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    html =
      view
      |> form("#basic-slot-form-form", %{"dynamic_form" => %{"subject" => "support"}})
      |> render_change()

    assert html =~ "Support Details"
  end

  test "group panel appears when its visible_if condition is met", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    html =
      view
      |> form("#group-slot-form-form", %{"dynamic_form" => %{"ship" => "true"}})
      |> render_change()

    assert html =~ "Shipping Address"
    assert html =~ "Street"
    assert html =~ "City"
  end

  test "in-progress input survives a parent re-render", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    html =
      view
      |> form("#basic-slot-form-form", %{"dynamic_form" => %{"name" => "Chris"}})
      |> render_change()

    assert html =~ ~s(value="Chris")

    # Re-render the parent LiveView; slot closures in form 3 change (they
    # capture @render_count), but form definitions are unchanged, so the
    # definition-equality guard must preserve the typed value.
    html =
      view
      |> element("button[phx-click=bump_render_count]")
      |> render_click()

    assert html =~ "count: 1"
    assert html =~ ~s(value="Chris")
  end

  test "custom control receives the changeset field and validates", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    html =
      view
      |> form("#custom-slot-form-form", %{
        "dynamic_form" => %{"attendees" => "5", "budget" => "500"}
      })
      |> render_change()

    # Tier 3 summary reads current form values
    assert html =~ "5"
    assert html =~ "500"

    # Numeric range validation from min/max flattened attrs (inline errors
    # surface on submit, when the changeset action is set)
    html =
      view
      |> form("#custom-slot-form-form", %{"dynamic_form" => %{"attendees" => "50"}})
      |> render_submit()

    assert html =~ "must be less than or equal to 20"
  end

  test "slot form submits through the backend", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    view
    |> form("#basic-slot-form-form", %{
      "dynamic_form" => %{
        "name" => "Chris",
        "email" => "chris@example.com",
        "subject" => "sales",
        "satisfaction" => "5"
      }
    })
    |> render_submit()

    assert render(view) =~ "Submission Results"
  end
end
