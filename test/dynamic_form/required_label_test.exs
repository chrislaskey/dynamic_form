defmodule DynamicForm.RequiredLabelTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.Changeset
  alias DynamicForm.Instance
  alias DynamicForm.Renderer

  @mark ~s(<span class="ml-0.5 text-red-500">*</span>)

  defp render_instance(instance, params \\ %{}) do
    changeset = Changeset.create_changeset(instance, params)

    render_component(&Renderer.Component.render/1,
      instance: instance,
      form: Phoenix.Component.to_form(changeset, as: "dynamic_form"),
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

  defp question(overrides) do
    %Instance{
      id: "required-label",
      elements: [
        struct!(
          %Instance.Question{name: "email", type: "text", title: "Email", isRequired: true},
          overrides
        )
      ]
    }
  end

  describe "the label the component receives" do
    test "is plain text, with no markup composed into it" do
      html = render_instance(question([]))

      # The mark is a sibling of the text, not markup composed into it
      assert html =~ "Email#{@mark}"
    end

    test "a question that is not required gets no mark" do
      refute render_instance(question(isRequired: false)) =~ @mark
    end
  end

  describe "the HTML required attribute" do
    test "is set on a required text input" do
      assert render_instance(question([])) =~ ~s(class="w-full input" required)
    end

    test "is absent when the question is not required" do
      html = render_instance(question(isRequired: false))

      assert html =~ ~s(class="w-full input")
      refute html =~ "required"
    end

    test "is set on select, textarea, and radio controls" do
      for {type, control} <- [
            {"dropdown", ~s(class="w-full select" required)},
            {"comment", ~s(class="w-full textarea" required)},
            {"radiogroup", ~s(value="a" required)}
          ] do
        assert render_instance(question(type: type, choices: ["a", "b"])) =~ control
      end
    end

    test "is left off a checkbox group, where it would demand every option" do
      html = render_instance(question(type: "checkbox", choices: ["a", "b"]))

      # The mark still renders, so the field reads as required
      assert html =~ @mark
      refute html =~ ~s(class="checkbox checkbox-sm" required)
    end
  end

  describe "required_label" do
    test "replaces the mark with a custom string" do
      html = render_instance(question(requiredLabel: "(required)"))

      assert html =~ ~S|<span class="ml-0.5 text-red-500">(required)</span>|
      refute html =~ @mark
    end

    test "blank suppresses the mark while the field stays required" do
      for blank <- [false, ""] do
        html = render_instance(question(requiredLabel: blank))

        refute html =~ "text-red-500"
        # Still required, in the DOM and in the changeset
        assert html =~ ~s(class="w-full input" required)
        refute Changeset.create_changeset(question(requiredLabel: blank), %{}).valid?
      end
    end

    test "a blank label suppresses the mark, since it has nothing to sit beside" do
      html = render_instance(question(title: false))

      refute html =~ "text-red-500"
    end
  end

  describe "other label sites" do
    test "a checkbox shows the mark beside its inline label" do
      html = render_instance(question(type: "boolean"))

      assert html =~ "Email#{@mark}"
    end

    test "a required nested form marks its section heading" do
      html =
        render_instance(%Instance{
          id: "required-label",
          elements: [
            %Instance.Question{
              name: "addresses",
              type: "paneldynamic",
              title: "Addresses",
              isRequired: true,
              templateElements: [%Instance.Question{name: "street", type: "text"}]
            }
          ]
        })

      assert html =~ "Addresses"
      assert html =~ ~s(class="ml-0.5 text-red-500")
    end

    test "a custom control's body keeps the library's label and mark" do
      entry = %{
        __slot__: :field,
        inner_block: fn _changed, field -> "BODY #{field.name}" end,
        type: "text",
        name: "email"
      }

      html = render_instance(question(slot: entry))

      assert html =~ "BODY dynamic_form[email]"
      assert html =~ @mark
    end
  end

  describe "Instance.required_label_text/1" do
    test "defaults to * and honours a custom or blank value" do
      assert Instance.required_label_text(%Instance.Question{name: "a", type: "text"}) == "*"

      assert Instance.required_label_text(%Instance.Question{
               name: "a",
               type: "text",
               requiredLabel: "(req)"
             }) == "(req)"

      for blank <- [false, ""] do
        q = %Instance.Question{name: "a", type: "text", requiredLabel: blank}
        assert Instance.required_label_text(q) == nil
      end
    end
  end
end
