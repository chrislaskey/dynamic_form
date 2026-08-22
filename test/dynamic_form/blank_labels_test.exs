defmodule DynamicForm.BlankLabelsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias DynamicForm.Changeset
  alias DynamicForm.Instance
  alias DynamicForm.Renderer

  defp render_instance(instance, params \\ %{}) do
    changeset = Changeset.create_changeset(instance, params)
    form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

    render_component(&Renderer.render/1,
      instance: instance,
      form: form,
      submit_text: "Submit",
      phx_submit: "submit",
      phx_change: "validate",
      target: nil,
      form_id: "test-form",
      disabled: false,
      hide_submit: false,
      gettext: DynamicForm.Gettext,
      uploads: %{},
      parent_id: nil
    )
  end

  defp instance_with(elements), do: %Instance{id: "blank-labels", elements: elements}

  # Rendered through real HEEx, because the difference between omitting an
  # attribute and passing nil is a difference in the slot entry's keys.
  defp declared(assigns) do
    ~H"""
    <DynamicForm.form id="blank-labels" render_only form={@form}>
      <:field type="text" name="omitted" required />
      <:field type="text" name="explicit_nil" label={nil} required />
      <:field type="text" name="explicit_false" label={false} required />
      <:field type="text" name="empty_string" label="" required />
      <:field type="text" name="given" label="Given" required />
    </DynamicForm.form>
    """
  end

  describe "a label set blank in declarative mode" do
    setup do
      assigns = %{form: Phoenix.Component.to_form(%{}, as: "dynamic_form")}
      %{html: rendered_to_string(declared(assigns))}
    end

    test "nil, false, and \"\" all render no label", %{html: html} do
      refute html =~ "Explicit_nil"
      refute html =~ "Explicit_false"
      refute html =~ "Empty_string"

      # Every field still renders its input
      for name <- ~w(explicit_nil explicit_false empty_string) do
        assert html =~ ~s(name="dynamic_form[#{name}]")
      end
    end

    test "a required field with a blank label shows no required marker", %{html: html} do
      # All five fields are required, but only the two with a label to mark get
      # a marker: "Given", and "Omitted" via the field-name fallback
      markers = html |> String.split(~s(<span class="ml-0.5 text-red-500">*</span>)) |> length()

      assert markers - 1 == 2
    end

    test "the label given as a string still renders, marker and all", %{html: html} do
      assert html =~ "Given"
      assert html =~ ~s(<span class="ml-0.5 text-red-500">*</span>)
    end

    test "omitting the attribute still falls back to the field name", %{html: html} do
      assert html =~ "Omitted"
    end
  end

  describe "a title set blank on a group" do
    test "renders no heading, while the members still render" do
      html =
        render_instance(
          instance_with([
            %Instance.Element{
              name: "totals",
              type: "panel",
              title: "",
              elements: [%Instance.Question{name: "amount", type: "text", title: "Amount"}]
            }
          ])
        )

      refute html =~ "<h3"
      assert html =~ ~s(name="dynamic_form[amount]")
    end
  end

  describe "a title set blank on a nested form" do
    defp nested(overrides) do
      instance_with([
        struct!(
          %Instance.Question{
            name: "addresses",
            type: "paneldynamic",
            templateElements: [%Instance.Question{name: "street", type: "text", title: "Street"}]
          },
          overrides
        )
      ])
    end

    test "renders no section heading, while the add button stays" do
      html = render_instance(nested(title: ""))

      refute html =~ "<h3"
      assert html =~ ~s(phx-click="add_nested_entry")
    end

    test "a blank entry_title renders no per-entry heading" do
      html = render_instance(nested(templateTitle: ""), %{"addresses" => [%{"street" => "x"}]})

      refute html =~ "<h4"
      assert html =~ ~s(name="dynamic_form[addresses][0][street]")
    end

    test "an entry_title of false does not raise" do
      html = render_instance(nested(templateTitle: false), %{"addresses" => [%{"street" => "x"}]})

      refute html =~ "<h4"
    end
  end

  describe "data mode" do
    test "a title of \"\" renders no label and no required marker" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "email", type: "text", title: "", isRequired: true}
          ])
        )

      refute html =~ "Email"
      refute html =~ ~s(<span class="ml-0.5 text-red-500">*</span>)
      # The label element is absent, not rendered empty
      refute html =~ ~s(<span class="label mb-1">)
      assert html =~ ~s(name="dynamic_form[email]")
    end

    test "a title of false renders no label" do
      html =
        render_instance(
          instance_with([%Instance.Question{name: "email", type: "text", title: false}])
        )

      refute html =~ "Email"
      assert html =~ ~s(name="dynamic_form[email]")
    end

    test "a title left unset still falls back to the capitalized name" do
      html =
        render_instance(
          instance_with([%Instance.Question{name: "email", type: "text", isRequired: true}])
        )

      assert html =~ "Email"
      assert html =~ ~s(<span class="ml-0.5 text-red-500">*</span>)
    end

    test "a blank label on a checkbox drops its inline description too" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "agree",
              type: "boolean",
              title: false,
              description: "Required to continue"
            }
          ])
        )

      refute html =~ "Required to continue"
      assert html =~ ~s(name="dynamic_form[agree]")
    end
  end

  describe "Instance.label_text/1" do
    test "falls back to the capitalized name only when the title is unset" do
      assert Instance.label_text(%Instance.Question{name: "email", type: "text"}) == "Email"

      for blank <- ["", false] do
        question = %Instance.Question{name: "email", type: "text", title: blank}
        assert Instance.label_text(question) == nil
      end
    end
  end
end
