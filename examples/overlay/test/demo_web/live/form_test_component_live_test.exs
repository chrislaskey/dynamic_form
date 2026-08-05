defmodule DemoWeb.FormTestComponentLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  # priority is optional but must be present: the browser submits "" for an
  # untouched number input, and create_changeset casts with empty_values: []
  # so "" fails the decimal cast
  @valid_params %{
    "dynamic_form" => %{
      "name" => "Chris Laskey",
      "email" => "chris@example.com",
      "subject" => "general",
      "message" => "Hello from the test suite",
      "priority" => "5"
    }
  }

  test "default mode delivers {:dynamic_form, payload} to the parent", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/form-test-component")

    view
    |> form("#contact-form-form", @valid_params)
    |> render_submit()

    html = render(view)
    assert html =~ "Form submitted successfully!"
    refute html =~ "Custom on_success:"
  end

  test "on_success replaces the default message", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/form-test-component")

    view
    |> element("form[phx-change=change_mode]")
    |> render_change(%{"mode" => "custom"})

    view
    |> form("#contact-form-form", @valid_params)
    |> render_submit()

    # The parent's {:custom_success, data} handler ran — not the default
    # {:dynamic_form, payload} handler
    assert render(view) =~ "Custom on_success:"
  end
end
