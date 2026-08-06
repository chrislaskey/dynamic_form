defmodule DemoWeb.ShowcaseFormLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders every question type from the JSON definition", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/showcase-form")

    # One input per question type: text, comment, dropdown, radiogroup
    # (rendered as radios), checkbox, boolean, rating, tagbox, file upload
    assert html =~ ~s(name="dynamic_form[name]")
    assert html =~ ~s(name="dynamic_form[message]")
    assert html =~ ~s(name="dynamic_form[subject]")
    assert html =~ ~s(name="dynamic_form[notification_method]")
    assert html =~ ~s(name="dynamic_form[interests][]")
    assert html =~ ~s(name="dynamic_form[subscribe]")
    assert html =~ ~s(name="dynamic_form[satisfaction]")
    assert html =~ ~s(name="dynamic_form[languages][]")
    assert html =~ ~s(type="file")
  end
end
