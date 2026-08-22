defmodule DynamicForm.FormDataTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.Changeset
  alias DynamicForm.Instance
  alias DynamicForm.Renderer

  defp slot_entry(attrs, inner_block) do
    attrs |> Map.new() |> Map.merge(%{__slot__: :field, inner_block: inner_block})
  end

  # A school form: "staff" entries drive a checkbox rendered inside every
  # "rooms" entry, and a custom element summarizes the whole form.
  defp instance do
    %Instance{
      id: "school",
      elements: [
        %Instance.Question{name: "name", type: "text", title: "Name"},
        %Instance.Question{
          name: "staff",
          type: "paneldynamic",
          title: "Staff",
          templateElements: [%Instance.Question{name: "name", type: "text", title: "Name"}]
        },
        %Instance.Question{
          name: "rooms",
          type: "paneldynamic",
          title: "Rooms",
          templateElements: [
            %Instance.Question{name: "label", type: "text", title: "Label"},
            %Instance.Question{
              name: "teachers",
              type: "checkbox",
              title: "Teachers",
              slot:
                slot_entry(%{type: "checkbox", name: "teachers"}, fn _changed, field ->
                  staff = DynamicForm.form_data(field)[:staff] || []

                  "[entry=#{field.form[:label].value}" <>
                    Enum.map_join(staff, "", &" teacher=#{&1[:name]}") <> "]"
                end)
            }
          ]
        },
        %Instance.Element{
          name: "summary",
          type: "custom",
          slot:
            slot_entry(%{type: "custom", name: "summary"}, fn _changed, form ->
              data = DynamicForm.form_data(form)

              "(summary name=#{data[:name] || "-"} staff=#{length(data[:staff] || [])})"
            end)
        }
      ]
    }
  end

  defp render_form(params) do
    changeset = Changeset.create_changeset(instance(), params)
    form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

    render_component(&Renderer.Component.render/1,
      instance: instance(),
      form: form,
      submit_text: "Submit",
      phx_submit: "submit",
      phx_change: "validate",
      target: nil,
      form_id: "school-form",
      disabled: false,
      hide_submit: false,
      gettext: DynamicForm.Gettext,
      uploads: %{},
      parent_id: nil
    )
  end

  @params %{
    "name" => "Ada Academy",
    "staff" => %{"0" => %{"name" => "Ada"}, "1" => %{"name" => "Grace"}},
    "rooms" => %{"0" => %{"label" => "Blue"}, "1" => %{"label" => "Red"}}
  }

  describe "inside a nested entry" do
    test "the body reads another nested form's entries" do
      html = render_form(@params)

      assert html =~ "[entry=Blue teacher=Ada teacher=Grace]"
      assert html =~ "[entry=Red teacher=Ada teacher=Grace]"
    end

    test "the body still reads its own entry through field.form" do
      html = render_form(%{@params | "staff" => %{}})

      assert html =~ "[entry=Blue]"
      assert html =~ "[entry=Red]"
    end

    test "renaming an entry changes what the other nested form sees" do
      html = render_form(%{@params | "staff" => %{"0" => %{"name" => "Ada Lovelace"}}})

      assert html =~ "[entry=Blue teacher=Ada Lovelace]"
      refute html =~ "teacher=Ada]"
    end
  end

  describe "in a custom element" do
    test "the body reads the same form-level data" do
      assert render_form(@params) =~ ~s[(summary name=Ada Academy staff=2)]
    end

    test "untouched values are absent rather than nil" do
      assert render_form(%{}) =~ ~s[(summary name=- staff=0)]
    end
  end

  describe "shape" do
    test "matches the payload data a :change message delivers" do
      changeset = Changeset.create_changeset(instance(), @params)
      payload = DynamicForm.Payload.new("school", changeset)

      assert %{name: "Ada Academy", staff: [%{name: "Ada"}, %{name: "Grace"}]} = payload.data

      # The slot body sees exactly that map: atom keys through nested entries.
      assert render_form(@params) =~ "teacher=Ada teacher=Grace"
    end
  end

  describe "outside a slot body" do
    test "raises on a form DynamicForm did not render" do
      form = Phoenix.Component.to_form(%{"name" => "Ada"}, as: "other")

      assert_raise ArgumentError, ~r/was not rendered by DynamicForm/, fn ->
        DynamicForm.form_data(form)
      end
    end
  end
end
