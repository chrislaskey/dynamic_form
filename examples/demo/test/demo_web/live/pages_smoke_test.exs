defmodule DemoWeb.PagesSmokeTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  @pages [
    "/",
    "/slot-forms",
    "/data-forms",
    "/showcase-form",
    "/nested-forms"
  ]

  for path <- @pages do
    test "GET #{path} renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, unquote(path))
      assert html =~ "DynamicForm"
    end
  end
end
