defmodule DemoWeb.PagesSmokeTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  @pages [
    "/",
    "/slot-forms",
    "/form-test",
    "/form-test-component",
    "/render",
    "/payment-form",
    "/showcase-form",
    "/section-form",
    "/nested-forms",
    "/surveyjs-test",
    "/builder-mockups"
  ]

  for path <- @pages do
    test "GET #{path} renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, unquote(path))
      assert html =~ "DynamicForm"
    end
  end
end
