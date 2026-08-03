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
