defmodule DemoWeb.FormTestComponentLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  # Optional fields (like the priority number input) are omitted: the ""
  # a browser submits for untouched inputs is treated as an empty value
  @valid_params %{
    "dynamic_form" => %{
      "name" => "Chris Laskey",
      "email" => "chris@example.com",
      "subject" => "general",
      "message" => "Hello from the test suite"
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
