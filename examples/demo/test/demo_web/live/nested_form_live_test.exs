defmodule DemoWeb.NestedFormLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "create mode seeds one empty address panel", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/nested-forms")

    assert html =~ ~s(name="dynamic_form[addresses][0][street]")
    refute html =~ ~s(name="dynamic_form[addresses][1][street]")
    assert html =~ "Add another address"
    # minPanelCount: 1 — the only panel can't be removed
    refute html =~ ~s(phx-click="remove_entry")
  end

  test "add_entry appends an entry, remove_entry deletes it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    html =
      view
      |> element(~s{button[phx-click="add_entry"][phx-value-path="addresses"]})
      |> render_click()

    assert html =~ ~s(name="dynamic_form[addresses][1][street]")
    assert html =~ "Address 2"
    # Two panels now — above minPanelCount, so remove buttons appear
    assert html =~ ~s(phx-click="remove_entry")

    html =
      view
      |> element(
        ~s{button[phx-click="remove_entry"][phx-value-path="addresses"][phx-value-index="1"]}
      )
      |> render_click()

    refute html =~ ~s(name="dynamic_form[addresses][1][street]")
  end

  test "add_entry preserves values already typed into other panels", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    view
    |> form("#nested-create-form-form")
    |> render_change(%{
      "dynamic_form" => %{
        "name" => "Ada",
        "addresses" => %{"0" => %{"kind" => "Home", "street" => "110 Main St"}}
      }
    })

    html =
      view
      |> element(~s{button[phx-click="add_entry"]})
      |> render_click()

    assert html =~ ~s(value="110 Main St")
    assert html =~ ~s(name="dynamic_form[addresses][1][street]")
  end

  test "invalid entries block submission and render inline errors", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    html =
      view
      |> form("#nested-create-form-form", %{
        "dynamic_form" => %{
          "name" => "Ada",
          "email" => "ada@example.com",
          "addresses" => %{
            "0" => %{"kind" => "Home", "street" => "", "city" => "Portland", "zip" => "bad"}
          }
        }
      })
      |> render_submit()

    refute html =~ "Submitted successfully"
    assert html =~ "can&#39;t be blank"
    assert html =~ "Enter a 5-digit ZIP code"
  end

  test "valid nested submission delivers nested data to the parent", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    view
    |> element(~s{button[phx-click="add_entry"]})
    |> render_click()

    view
    |> form("#nested-create-form-form", %{
      "dynamic_form" => %{
        "name" => "Ada Lovelace",
        "email" => "ada@example.com",
        "addresses" => %{
          "0" => %{"kind" => "Home", "street" => "110 Main St", "city" => "Portland"},
          "1" => %{"kind" => "Work", "street" => "13 Dearborn", "city" => "Boston"}
        }
      }
    })
    |> render_submit()

    # The success payload message is processed after the submit event, so
    # re-render to observe the parent's update
    html = render(view)

    assert html =~ "Submitted successfully"
    assert html =~ "110 Main St"
    assert html =~ "13 Dearborn"
  end

  test "keyName duplicates are rejected", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    view
    |> element(~s{button[phx-click="add_entry"]})
    |> render_click()

    html =
      view
      |> form("#nested-create-form-form", %{
        "dynamic_form" => %{
          "name" => "Ada",
          "email" => "ada@example.com",
          "addresses" => %{
            "0" => %{"kind" => "Home", "street" => "110 Main St", "city" => "Portland"},
            "1" => %{"kind" => "Home", "street" => "13 Dearborn", "city" => "Boston"}
          }
        }
      })
      |> render_submit()

    refute html =~ "Submitted successfully"
    assert html =~ "You already have an address of this type."
  end

  test "edit mode renders pre-populated panels", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    html =
      view
      |> element(~s{button[phx-value-mode="edit"]})
      |> render_click()

    assert html =~ ~s(value="110 Main Street")
    assert html =~ ~s(value="13 Dearborn")
    assert html =~ ~s(name="dynamic_form[addresses][1][city]")
  end

  test "conditional {panel.kind} field appears per entry", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    refute render(view) =~ ~s(name="dynamic_form[addresses][0][label]")

    html =
      view
      |> form("#nested-create-form-form")
      |> render_change(%{
        "dynamic_form" => %{"addresses" => %{"0" => %{"kind" => "Other"}}}
      })

    assert html =~ ~s(name="dynamic_form[addresses][0][label]")
  end
end
