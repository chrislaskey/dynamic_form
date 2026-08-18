defmodule DynamicForm.SlotRenderingTest do
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
    %Instance{id: "slot-render-test", elements: elements}
  end

  defp slot_entry(attrs, inner_block) do
    attrs |> Map.new() |> Map.merge(%{__slot__: :field, inner_block: inner_block})
  end

  describe "html elements with slot bodies (tier 1)" do
    test "renders the slot body instead of the html string" do
      entry = slot_entry(%{type: "html", name: "intro"}, fn _, _ -> "CUSTOM BODY CONTENT" end)

      html =
        render_instance(
          instance_with([
            %Instance.Element{name: "intro", type: "html", slot: entry}
          ])
        )

      assert html =~ "CUSTOM BODY CONTENT"
    end

    test "html elements without a slot still render the html string" do
      html =
        render_instance(
          instance_with([
            %Instance.Element{name: "intro", type: "html", html: "<h2>Raw HTML</h2>"}
          ])
        )

      assert html =~ "<h2>Raw HTML</h2>"
    end
  end

  describe "slot bodies inside nested form templates" do
    test "renders the same body once per entry with per-entry fields" do
      entry =
        slot_entry(%{type: "text", name: "street"}, fn _, field ->
          "CUSTOM name=#{field.name} value=#{field.value}"
        end)

      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "addresses",
              type: "paneldynamic",
              templateElements: [
                %Instance.Question{name: "street", type: "text", title: "Street", slot: entry}
              ]
            }
          ]),
          %{
            "addresses" => [
              %{"street" => "110 Main St"},
              %{"street" => "13 Dearborn"}
            ]
          }
        )

      assert html =~ "CUSTOM name=dynamic_form[addresses][0][street] value=110 Main St"
      assert html =~ "CUSTOM name=dynamic_form[addresses][1][street] value=13 Dearborn"
    end

    test "a custom element's body reads the entry's position as form.index" do
      entry =
        slot_entry(%{type: "custom", name: "position"}, fn _, form ->
          "POSITION index=#{inspect(form.index)} number=#{form.index + 1}"
        end)

      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "addresses",
              type: "paneldynamic",
              templateElements: [%Instance.Element{name: "position", type: "custom", slot: entry}]
            }
          ]),
          %{"addresses" => [%{}, %{}, %{}]}
        )

      # Zero-based, like Phoenix's own inputs_for; {panelIndex} is one-based
      assert html =~ "POSITION index=0 number=1"
      assert html =~ "POSITION index=1 number=2"
      assert html =~ "POSITION index=2 number=3"
    end

    test "a control body reads it through field.form.index" do
      entry =
        slot_entry(%{type: "text", name: "street"}, fn _, field ->
          "ROW #{field.form.index}"
        end)

      html =
        render_instance(
          instance_with([
            %Instance.Question{
              name: "addresses",
              type: "paneldynamic",
              templateElements: [
                %Instance.Question{name: "street", type: "text", slot: entry}
              ]
            }
          ]),
          %{"addresses" => [%{"street" => "a"}, %{"street" => "b"}]}
        )

      assert html =~ "ROW 0"
      assert html =~ "ROW 1"
    end

    test "the form-level form has no index" do
      entry =
        slot_entry(%{type: "custom", name: "position"}, fn _, form ->
          "TOP index=#{inspect(form.index)}"
        end)

      html =
        render_instance(
          instance_with([%Instance.Element{name: "position", type: "custom", slot: entry}])
        )

      assert html =~ "TOP index=nil"
    end
  end

  describe "questions with slot bodies (tier 2)" do
    test "renders label and passes the form field to the body" do
      entry =
        slot_entry(%{type: "text", name: "amount"}, fn _, field ->
          "CUSTOM CONTROL name=#{field.name} id=#{field.id}"
        end)

      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "amount", type: "text", title: "Amount", slot: entry}
          ])
        )

      assert html =~ "Amount"
      assert html =~ "CUSTOM CONTROL name=dynamic_form[amount] id=test-form_amount"
    end

    test "renders validation errors around the custom control" do
      entry = slot_entry(%{type: "text", name: "email"}, fn _, _field -> "CUSTOM" end)

      instance =
        instance_with([
          %Instance.Question{
            name: "email",
            type: "text",
            title: "Email",
            isRequired: true,
            slot: entry
          }
        ])

      changeset =
        instance
        |> Changeset.create_changeset(%{"email" => ""})
        |> Map.put(:action, :validate)

      form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

      html =
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

      assert html =~ "CUSTOM"
      assert html =~ "can&#39;t be blank"
    end
  end

  describe "custom elements (tier 3)" do
    test "passes the whole form to the body" do
      entry =
        slot_entry(%{type: "custom", name: "summary"}, fn _, form ->
          "SUMMARY quantity=#{Phoenix.HTML.Form.input_value(form, :quantity)}"
        end)

      html =
        render_instance(
          instance_with([
            %Instance.Question{name: "quantity", type: "text", title: "Quantity"},
            %Instance.Element{name: "summary", type: "custom", slot: entry}
          ]),
          %{"quantity" => "42"}
        )

      assert html =~ "SUMMARY quantity=42"
    end
  end
end
