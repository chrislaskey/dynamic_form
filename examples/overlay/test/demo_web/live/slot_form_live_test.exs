defmodule DemoWeb.SlotFormLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders all slot-defined forms", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/slot-forms")

    # Basic form fields
    assert html =~ "Email Address"
    assert html =~ "Subject"
    assert html =~ "Satisfaction"

    # visible_if fields start hidden. Match on rendered input names — the
    # page text mentions these fields in the definition code blocks.
    refute html =~ ~s(name="dynamic_form[details]")
    refute html =~ ~s(name="dynamic_form[street]")

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

    assert html =~ ~s(name="dynamic_form[details]")
  end

  test "group panel appears when its visible_if condition is met", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    html =
      view
      |> form("#group-slot-form-form", %{"dynamic_form" => %{"ship" => "true"}})
      |> render_change()

    assert html =~ ~s(name="dynamic_form[street]")
    assert html =~ ~s(name="dynamic_form[city]")
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

  test "notifies the parent with an {:error, payload} outcome on a failed submission", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, "/slot-forms")

    # Required fields missing — Demo.Submissions.submit/2 gates on changeset.valid?
    view
    |> form("#basic-slot-form-form", %{"dynamic_form" => %{"name" => "x"}})
    |> render_submit()

    # The parent's {:dynamic_form_submit, id, {:error, payload}} handler flashes
    assert render(view) =~ "has errors"
  end

  test "slot form submits through on_submit", %{conn: conn} do
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

  test "on_change adds live cross-field validation", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    # $100 for 5 attendees violates the $50-per-attendee on_change rule
    view
    |> form("#custom-slot-form-form", %{
      "dynamic_form" => %{"attendees" => "5", "budget" => "100"}
    })
    |> render_submit()

    assert render(view) =~ "must be at least $50 per attendee"

    # Fixing the budget clears the error live, without another submit
    html =
      view
      |> form("#custom-slot-form-form", %{
        "dynamic_form" => %{"attendees" => "5", "budget" => "500"}
      })
      |> render_change()

    refute html =~ "must be at least $50 per attendee"
  end

  test "on_submit {:error, changeset} renders context errors on the form", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/slot-forms")

    # Demo.Submissions.create/1 rejects this email with {:error, changeset}
    view
    |> form("#basic-slot-form-form", %{
      "dynamic_form" => %{
        "name" => "Chris",
        "email" => "taken@example.com",
        "subject" => "sales",
        "satisfaction" => "5"
      }
    })
    |> render_submit()

    html = render(view)
    assert html =~ "has already been taken"
    refute html =~ "Submission Results"
  end
end
