defmodule DynamicForm.RendererTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.{Changeset, Instance, Renderer}

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

  defp instance_with(elements) do
    %Instance{id: "render-test", elements: elements}
  end

  describe "question types" do
    test "renders text questions with inputType" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "email", type: "text", inputType: "email", title: "Email"}
          ])
        )

      assert html =~ ~s(type="email")
      assert html =~ "Email"
    end

    test "renders comment questions as textareas" do
      html =
        render_instance(
          instance_with([%Instance.Question{name: "bio", type: "comment", title: "Bio"}])
        )

      assert html =~ "<textarea"
    end

    test "renders dropdown questions with tuple and string choices" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "subject",
              type: "dropdown",
              title: "Subject",
              choices: [{"General", "general"}, "Other"]
            }
          ])
        )

      assert html =~ "<select"
      assert html =~ ~s(value="general")
      assert html =~ "General"
      assert html =~ ~s(value="Other")
    end

    test "renders radiogroup questions including plain string choices" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "color",
              type: "radiogroup",
              title: "Color",
              choices: ["Red", "Blue"]
            }
          ])
        )

      assert html =~ ~s(type="radio")
      assert html =~ ~s(value="Red")
      assert html =~ ~s(value="Blue")
    end

    test "renders checkbox questions as a checkbox group" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "toppings",
              type: "checkbox",
              title: "Toppings",
              choices: [{"Cheese", "cheese"}, {"Olives", "olives"}]
            }
          ])
        )

      assert html =~ ~s(type="checkbox")
      assert html =~ ~s(name="dynamic_form[toppings][]")
      assert html =~ ~s(value="cheese")
      assert html =~ ~s(value="olives")
    end

    test "renders tagbox questions as a multiple select" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "tags",
              type: "tagbox",
              title: "Tags",
              choices: ["a", "b"]
            }
          ])
        )

      assert html =~ "<select"
      assert html =~ "multiple"
      assert html =~ ~s(name="dynamic_form[tags][]")
    end

    test "renders rating questions as numeric radio buttons over the rate range" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "score",
              type: "rating",
              title: "Score",
              rateMin: 1,
              rateMax: 3
            }
          ])
        )

      assert html =~ ~s(type="radio")
      assert html =~ ~s(value="1")
      assert html =~ ~s(value="3")
      refute html =~ ~s(value="4")
    end

    test "renders boolean questions as a single checkbox" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "agree", type: "boolean", title: "Agree?"}
          ])
        )

      assert html =~ ~s(type="checkbox")
      assert html =~ "Agree?"
    end

    test "renders a fallback box for unknown question types" do
      html =
        render_instance(
          instance_with([%Instance.Question{name: "mystery", type: "signaturepad"}])
        )

      assert html =~ "Unknown question type"
      assert html =~ "signaturepad"
    end

    test "marks required questions with an indicator" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "email", type: "text", title: "Email", isRequired: true}
          ])
        )

      assert html =~ "*"
    end
  end

  describe "element types" do
    test "renders html elements" do
      html =
        render_instance(
          instance_with([
            %Instance.Element{name: "intro", type: "html", html: "<h2>Welcome</h2>"}
          ])
        )

      assert html =~ "<h2>Welcome</h2>"
    end

    test "renders panels with nested questions" do
      html =
        render_instance(
          instance_with([
            %Instance.Element{
              name: "panel",
              type: "panel",
              title: "Address",
              elements: [%Instance.Question{name: "city", type: "text", title: "City"}]
            }
          ])
        )

      assert html =~ "Address"
      assert html =~ "City"
    end

    test "renders image elements" do
      html =
        render_instance(
          instance_with([
            %Instance.Element{
              name: "logo",
              type: "image",
              imageLink: "https://example.com/logo.png",
              imageWidth: "100%",
              imageFit: "cover"
            }
          ])
        )

      assert html =~ ~s(src="https://example.com/logo.png")
      assert html =~ "width: 100%;"
      assert html =~ "object-fit: cover;"
    end
  end

  describe "conditional logic" do
    test "hides questions whose visibleIf is not met" do
      instance =
        instance_with([
          %Instance.Question{name: "payment", type: "dropdown", choices: ["card", "cash"]},
          %Instance.Question{
            name: "card_number",
            type: "text",
            title: "Card Number",
            visibleIf: "{payment} = 'card'"
          }
        ])

      hidden = render_instance(instance, %{"payment" => "cash"})
      refute hidden =~ "Card Number"

      shown = render_instance(instance, %{"payment" => "card"})
      assert shown =~ "Card Number"
    end

    test "disables questions whose enableIf is not met" do
      instance =
        instance_with([
          %Instance.Question{name: "unlock", type: "boolean"},
          %Instance.Question{
            name: "secret",
            type: "text",
            title: "Secret",
            enableIf: "{unlock} = true"
          }
        ])

      disabled = render_instance(instance, %{"unlock" => "false"})
      assert disabled =~ "disabled"

      enabled = render_instance(instance, %{"unlock" => "true"})
      refute enabled =~ ~s(<input type="text" disabled)
    end

    test "readOnly questions render disabled" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "id", type: "text", title: "ID", readOnly: true}
          ])
        )

      assert html =~ "disabled"
    end
  end
end
