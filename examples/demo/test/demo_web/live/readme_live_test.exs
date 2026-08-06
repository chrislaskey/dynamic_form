defmodule DemoWeb.ReadmeLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders every README example form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    for id <- ~w(readme-contact readme-support readme-checkout readme-json readme-data) do
      assert html =~ ~s(id="#{id}-form")
    end
  end

  test "contact form runs the full lifecycle: on_submit errors, then success", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    # The on_submit callback batches the fake uniqueness check with the
    # built-in errors and renders them inline
    view
    |> form("#readme-contact-form", %{
      "dynamic_form" => %{"name" => "Jamie", "email" => "taken@example.com"}
    })
    |> render_submit()

    assert render(view) =~ "has already been taken"

    # A valid submission messages the parent, which flashes
    view
    |> form("#readme-contact-form", %{
      "dynamic_form" => %{"name" => "Jamie", "email" => "jamie@example.com"}
    })
    |> render_submit()

    assert render(view) =~ "submitted successfully"
  end

  test "data attribute prefills the JSON-defined form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "hello@world.com"
  end
end
