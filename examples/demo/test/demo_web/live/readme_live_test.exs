defmodule DemoWeb.ReadmeLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders every README example form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    ids =
      ~w(readme-basic readme-data readme-lifecycle readme-support readme-styling readme-grouping readme-nested readme-json readme-render-only)

    for id <- ids do
      assert html =~ ~s(id="#{id}-form")
    end
  end

  test "basic form messages the parent on a valid submission", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#readme-basic-form", %{
      "dynamic_form" => %{"name" => "Jamie", "email" => "jamie@example.com"}
    })
    |> render_submit()

    assert render(view) =~ "submitted successfully"
  end

  test "on_submit batches the uniqueness check with built-in errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    view
    |> form("#readme-lifecycle-form", %{
      "dynamic_form" => %{"name" => "Jamie", "email" => "taken@example.com"}
    })
    |> render_submit()

    assert render(view) =~ "has already been taken"
  end

  test "data attribute prefills the form", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "hello@world.com"
  end

  test "nested form seeds one address entry with an add button", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ ~s(name="dynamic_form[addresses][0][street]")
    assert html =~ "Add address"
  end

  test "render-only form events are handled by this LiveView", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    # Invalid: the parent's own changeset produces the error
    html =
      view
      |> form("#readme-render-only-form", %{"contact" => %{"name" => "Jamie", "email" => ""}})
      |> render_submit()

    assert html =~ "can&#39;t be blank"

    # Valid: the parent's handle_event("save", ...) flashes
    view
    |> form("#readme-render-only-form", %{
      "contact" => %{"name" => "Jamie", "email" => "jamie@example.com"}
    })
    |> render_submit()

    assert render(view) =~ "Contact saved"
  end
end
