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

    test "renders nothing for unknown question types" do
      html =
        render_instance(
          instance_with([%Instance.Question{name: "mystery", type: "signaturepad"}])
        )

      # An absent field is obvious in testing without looking broken in
      # production; registered custom field types dispatch to the components
      # module instead (see custom_field_types_test.exs)
      refute html =~ "signaturepad"
      refute html =~ "mystery"
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

    test "readOnly text questions render readonly, so their value still submits" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "id", type: "text", title: "ID", readOnly: true}
          ]),
          %{"id" => "abc-123"}
        )

      assert html =~ "readonly"
      refute html =~ "disabled"
    end

    test "readOnly questions HTML has no readonly for render disabled plus a hidden value" do
      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "size",
              type: "dropdown",
              title: "Size",
              choices: ["S", "M"],
              readOnly: true
            }
          ]),
          %{"size" => "M"}
        )

      assert html =~ "disabled"
      assert html =~ ~s(<input type="hidden" name="dynamic_form[size]" value="M">)
    end
  end

  describe "paneldynamic questions" do
    defp addresses_question(overrides) do
      struct!(
        %Instance.Question{
          name: "addresses",
          type: "paneldynamic",
          title: "Addresses",
          templateElements: [
            %Instance.Question{name: "street", type: "text", title: "Street"},
            %Instance.Question{name: "city", type: "text", title: "City"}
          ]
        },
        overrides
      )
    end

    test "renders one namespaced sub-form per entry" do
      html =
        render_instance(
          instance_with([addresses_question([])]),
          %{
            "addresses" => [
              %{"street" => "110 Main St", "city" => "Portland"},
              %{"street" => "13 Dearborn", "city" => "Boston"}
            ]
          }
        )

      assert html =~ ~s(name="dynamic_form[addresses][0][street]")
      assert html =~ ~s(name="dynamic_form[addresses][1][street]")
      assert html =~ ~s(value="110 Main St")
      assert html =~ ~s(value="13 Dearborn")
    end

    test "renders add and remove buttons with the question path" do
      html =
        render_instance(
          instance_with([addresses_question(addPanelText: "Add address")]),
          %{"addresses" => [%{"street" => "x", "city" => "y"}]}
        )

      assert html =~ ~s(phx-click="add_nested_entry")
      assert html =~ ~s(phx-value-path="addresses")
      assert html =~ "Add address"
      assert html =~ ~s(phx-click="remove_nested_entry")
      assert html =~ ~s(phx-value-index="0")
    end

    test "renders templateTitle with panelIndex substitution" do
      html =
        render_instance(
          instance_with([addresses_question(templateTitle: "Address {panelIndex}")]),
          %{"addresses" => [%{}, %{}]}
        )

      assert html =~ "Address 1"
      assert html =~ "Address 2"
    end

    test "renders noEntriesText and no remove button when empty" do
      html =
        render_instance(
          instance_with([addresses_question(noEntriesText: "No addresses yet.")]),
          %{"addresses" => []}
        )

      assert html =~ "No addresses yet."
      refute html =~ ~s(phx-click="remove_nested_entry")
    end

    test "hides add at maxPanelCount and remove at minPanelCount" do
      html =
        render_instance(
          instance_with([addresses_question(minPanelCount: 1, maxPanelCount: 1)]),
          %{"addresses" => [%{"street" => "x", "city" => "y"}]}
        )

      refute html =~ ~s(phx-click="add_nested_entry")
      refute html =~ ~s(phx-click="remove_nested_entry")
    end

    test "confirmDelete adds a data-confirm attribute" do
      html =
        render_instance(
          instance_with([
            addresses_question(confirmDelete: true, confirmDeleteText: "Really remove?")
          ]),
          %{"addresses" => [%{}, %{}]}
        )

      assert html =~ ~s(data-confirm="Really remove?")
    end

    test "always renders a hidden input so removing every panel persists" do
      html = render_instance(instance_with([addresses_question([])]))

      assert html =~ ~s(name="dynamic_form[addresses][__empty__]")
    end

    test "template visibleIf with {panel.field} scopes per entry" do
      question =
        addresses_question(
          templateElements: [
            %Instance.Question{name: "kind", type: "dropdown", choices: ["Home", "Other"]},
            %Instance.Question{
              name: "label",
              type: "text",
              title: "Custom label",
              visibleIf: "{panel.kind} = 'Other'"
            }
          ]
        )

      html =
        render_instance(
          instance_with([question]),
          %{"addresses" => [%{"kind" => "Home"}, %{"kind" => "Other"}]}
        )

      refute html =~ ~s(name="dynamic_form[addresses][0][label]")
      assert html =~ ~s(name="dynamic_form[addresses][1][label]")
    end

    test "nested paneldynamic renders with dotted paths" do
      instance =
        instance_with([
          %Instance.Question{
            name: "contacts",
            type: "paneldynamic",
            templateElements: [
              %Instance.Question{name: "contact_name", type: "text"},
              %Instance.Question{
                name: "phones",
                type: "paneldynamic",
                templateElements: [
                  %Instance.Question{name: "number", type: "text"}
                ]
              }
            ]
          }
        ])

      html =
        render_instance(instance, %{
          "contacts" => [%{"contact_name" => "Ada", "phones" => [%{"number" => "555"}]}]
        })

      assert html =~ ~s(name="dynamic_form[contacts][0][phones][0][number]")
      assert html =~ ~s(phx-value-path="contacts.0.phones")
    end
  end
end
