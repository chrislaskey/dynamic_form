defmodule DemoWeb.NestedFormLiveTest do
  use DemoWeb.ConnCase

  import Phoenix.LiveViewTest

  test "create mode seeds one empty address panel", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/nested-forms")

    assert html =~ ~s(name="dynamic_form[addresses][0][street]")
    refute html =~ ~s(name="dynamic_form[addresses][1][street]")
    assert html =~ "Add another address"
    # minPanelCount: 1 — the only panel can't be removed
    refute html =~ ~s(phx-click="remove_nested_entry")
  end

  test "add_nested_entry appends an entry, remove_nested_entry deletes it", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/nested-forms")

    html =
      view
      |> element(~s{button[phx-click="add_nested_entry"][phx-value-path="addresses"]})
      |> render_click()

    assert html =~ ~s(name="dynamic_form[addresses][1][street]")
    assert html =~ "Address 2"
    # Two panels now — above minPanelCount, so remove buttons appear
    assert html =~ ~s(phx-click="remove_nested_entry")

    html =
      view
      |> element(
        ~s{button[phx-click="remove_nested_entry"][phx-value-path="addresses"][phx-value-index="1"]}
      )
      |> render_click()

    refute html =~ ~s(name="dynamic_form[addresses][1][street]")
  end

  test "add_nested_entry preserves values already typed into other panels", %{conn: conn} do
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
      |> element(~s{button[phx-click="add_nested_entry"]})
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
    |> element(~s{button[phx-click="add_nested_entry"]})
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
    |> element(~s{button[phx-click="add_nested_entry"]})
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

  describe "declarative (slot) mode" do
    defp switch_to_slots(view) do
      view
      |> element(~s{button[phx-value-mode="slots"]})
      |> render_click()
    end

    test "renders the slot-defined nested form with one seeded entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/nested-forms")

      html = switch_to_slots(view)

      assert html =~ ~s(name="dynamic_form[milestones][0][title]")
      assert html =~ "Milestone 1"
      assert html =~ "Add milestone"
      # The <:group> panel renders inside the entry
      assert html =~ "Schedule"
      assert html =~ ~s(name="dynamic_form[milestones][0][quarter]")
    end

    test "entries render through the components module's nested_entry/1", %{conn: conn} do
      {:ok, view, html} = live(conn, "/nested-forms")

      # Create mode uses the library's built-in entry container
      assert html =~ "mt-3 rounded-lg border border-gray-200 p-4"
      refute html =~ "border-indigo-400"

      # Slots mode passes components={DemoWeb.FormComponents}, whose
      # nested_entry/1 replaces the container
      html = switch_to_slots(view)

      assert html =~ "border-indigo-400"
      refute html =~ "mt-3 rounded-lg border border-gray-200 p-4"
    end

    test "custom :let control renders per entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/nested-forms")
      switch_to_slots(view)

      html =
        view
        |> element(~s{button[phx-click="add_nested_entry"][phx-value-path="milestones"]})
        |> render_click()

      assert html =~ ~s(type="range")
      assert html =~ ~s(name="dynamic_form[milestones][0][effort]")
      assert html =~ ~s(name="dynamic_form[milestones][1][effort]")
    end

    test "entries validate independently and submit as nested data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/nested-forms")
      switch_to_slots(view)

      html =
        view
        |> form("#nested-slot-form-form", %{
          "dynamic_form" => %{
            "project" => "Apollo",
            "milestones" => %{
              "0" => %{"title" => "", "quarter" => "Q1"}
            }
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"

      view
      |> form("#nested-slot-form-form", %{
        "dynamic_form" => %{
          "project" => "Apollo",
          "milestones" => %{
            "0" => %{"title" => "Design", "effort" => "10", "quarter" => "Q1"}
          }
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "Submitted successfully"
      assert html =~ "Design"
    end
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
