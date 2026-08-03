defmodule DemoWeb.SectionFormLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the form from a JSON string via the json attribute", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/section-form")

    # JSON mode is the default
    assert html =~ "json="
    assert html =~ ~s(id="section-form-form")
    assert html =~ ~s(name="dynamic_form[first_name]")
  end

  test "toggles between json and instance modes", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/section-form")

    html =
      view
      |> element("button[phx-click=toggle_format]")
      |> render_click()

    # Struct mode renders the same form
    assert html =~ "instance="
    assert html =~ ~s(name="dynamic_form[first_name]")

    # And back to JSON mode
    html =
      view
      |> element("button[phx-click=toggle_format]")
      |> render_click()

    assert html =~ "json="
    assert html =~ ~s(name="dynamic_form[first_name]")
  end
end
