defmodule DemoWeb.DataFormLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  # Optional fields omitted: the "" a browser submits for untouched inputs
  # is treated as an empty value
  @valid_contact_params %{
    "dynamic_form" => %{
      "name" => "Chris Laskey",
      "email" => "chris@example.com",
      "subject" => "general",
      "message" => "Hello from the test suite"
    }
  }

  test "visibleIf reveals payment fields for the selected method", %{conn: conn} do
    {:ok, view, html} = live(conn, "/data-forms")

    # Conditional fields start hidden
    refute html =~ ~s(name="dynamic_form[card_number]")
    refute html =~ ~s(name="dynamic_form[paypal_email]")

    html =
      view
      |> form("#payment-form-form", %{"dynamic_form" => %{"payment_method" => "credit_card"}})
      |> render_change()

    assert html =~ ~s(name="dynamic_form[card_number]")
    refute html =~ ~s(name="dynamic_form[paypal_email]")
  end

  test "panels form toggles between json and instance modes", %{conn: conn} do
    {:ok, view, html} = live(conn, "/data-forms")

    # JSON mode is the default
    assert html =~ ~s(id="panels-form-form")
    assert html =~ ~s(name="dynamic_form[first_name]")

    # Struct mode renders the same form
    html =
      view
      |> element("button[phx-click=toggle_format]")
      |> render_click()

    assert html =~ ~s(name="dynamic_form[first_name]")
  end

  test "create mode delivers {:dynamic_form, :success, payload} to the parent", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/data-forms")

    view
    |> form("#contact-create-form", @valid_contact_params)
    |> render_submit()

    html = render(view)
    assert html =~ "submitted successfully"
    refute html =~ "via on_success"
  end

  test "edit mode prefills via struct data without raising", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/data-forms")

    html =
      view
      |> element("form[phx-change=change_mode]")
      |> render_change(%{"mode" => "edit_struct"})

    assert html =~ ~s(value="Jane Smith")
    assert html =~ ~s(value="jane.smith@example.com")

    view
    |> form("#contact-edit-form", %{
      "dynamic_form" => Map.delete(@valid_contact_params["dynamic_form"], "email")
    })
    |> render_submit()

    assert render(view) =~ "via on_success"
  end

  test "edit mode prefills via data, locks email, and uses on_success", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/data-forms")

    html =
      view
      |> element("form[phx-change=change_mode]")
      |> render_change(%{"mode" => "edit"})

    # Prefilled from sample_edit_data/0, with the readOnly email field
    # rendered as a readonly input — not editable, but still submitted
    assert html =~ ~s(value="Jane Smith")
    assert html =~ ~s(value="jane.smith@example.com")
    [_, email_input] = String.split(html, ~s(id="contact-edit-form_email"), parts: 2)
    [email_input | _] = String.split(email_input, "/>", parts: 2)
    assert email_input =~ "readonly"

    # The on_success callback replaces the default message.
    view
    |> form("#contact-edit-form", %{
      "dynamic_form" => Map.delete(@valid_contact_params["dynamic_form"], "email")
    })
    |> render_submit()

    assert render(view) =~ "via on_success"
  end
end
