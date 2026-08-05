defmodule DynamicForm.ComponentsTest do
  # Not async: some tests set the :dynamic_form, :components application config
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias DynamicForm.{Components, Instance}

  # A partial components module: owns input/1, button/1, and
  # translate_error/1; everything else (radio groups, labels, errors,
  # sections) must fall back to the built-ins.
  defmodule CustomComponents do
    use Phoenix.Component

    def input(assigns) do
      ~H"""
      <div data-custom-input={@field.name}>
        <input type={@type} name={@field.name} id={@field.id} value={@field.value} />
      </div>
      """
    end

    def button(assigns) do
      ~H"""
      <button data-custom-button type={@type} disabled={@disabled}>
        {render_slot(@inner_block)}
      </button>
      """
    end

    def translate_error({msg, _opts}), do: "custom: " <> msg
  end

  @instance %Instance{
    id: "components-test",
    elements: [
      %Instance.Question{name: "name", type: "text", title: "Name"},
      %Instance.Question{
        name: "color",
        type: "radiogroup",
        title: "Color",
        choices: ["red", "blue"]
      }
    ]
  }

  defp render_form(overrides \\ []) do
    changeset = DynamicForm.Changeset.create_changeset(@instance, %{})
    form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

    assigns =
      Keyword.merge(
        [id: "components-test", render_only: true, instance: @instance, form: form],
        overrides
      )

    render_component(&DynamicForm.form/1, assigns)
  end

  describe "resolve/1" do
    test "nil without config resolves to nil (built-in only)" do
      assert Components.resolve(nil) == nil
    end

    test "nil falls back to the application config" do
      Application.put_env(:dynamic_form, :components, CustomComponents)
      on_exit(fn -> Application.delete_env(:dynamic_form, :components) end)

      assert Components.resolve(nil) == CustomComponents
    end

    test "a per-form module wins over the application config" do
      Application.put_env(:dynamic_form, :components, DynamicForm.CoreComponents)
      on_exit(fn -> Application.delete_env(:dynamic_form, :components) end)

      assert Components.resolve(CustomComponents) == CustomComponents
    end

    test "raises on a module that cannot be loaded" do
      assert_raise ArgumentError, ~r/could not be loaded/, fn ->
        Components.resolve(DynamicForm.NoSuchComponents)
      end
    end
  end

  describe "provides?/2" do
    test "true only for exported 1-arity functions" do
      assert Components.provides?(CustomComponents, :input)
      assert Components.provides?(CustomComponents, :translate_error)
      refute Components.provides?(CustomComponents, :input_radio_group)
      refute Components.provides?(nil, :input)
    end
  end

  describe "translate_error/3" do
    test "delegates when the module exports translate_error/1" do
      assert Components.translate_error(CustomComponents, {"is invalid", []}) ==
               "custom: is invalid"
    end

    test "falls back to the built-in translation" do
      assert Components.translate_error(nil, {"is invalid", []}) == "is invalid"
    end
  end

  describe "rendering with a custom components module" do
    test "delegates exported functions and falls back for the rest" do
      html = render_form(components: CustomComponents)

      # input/1 delegated: custom markup for the text question
      assert html =~ ~s(data-custom-input="dynamic_form[name]")

      # input_radio_group/1 not exported: built-in radio group renders
      assert html =~ ~s(type="radio")
      assert html =~ ~s(name="dynamic_form[color]")
      refute html =~ ~s(data-custom-input="dynamic_form[color]")

      # button/1 delegated: custom submit button replaces the built-in
      assert html =~ "data-custom-button"
      refute html =~ "bg-indigo-600"
    end

    test "without a components module everything renders built-in" do
      html = render_form()

      refute html =~ "data-custom"
      assert html =~ "bg-indigo-600"
    end

    test "the application config applies without a per-form attribute" do
      Application.put_env(:dynamic_form, :components, CustomComponents)
      on_exit(fn -> Application.delete_env(:dynamic_form, :components) end)

      html = render_form()

      assert html =~ ~s(data-custom-input="dynamic_form[name]")
    end

    test "custom-control slot bodies fall back to built-in label and error" do
      entry = %{
        __slot__: :field,
        inner_block: fn _changed, field -> "CUSTOM CONTROL #{field.name}" end,
        type: "text",
        name: "name",
        label: "Name"
      }

      changeset =
        DynamicForm.Changeset.create_changeset(
          %Instance{
            id: "slot-test",
            elements: [
              %Instance.Question{
                name: "name",
                type: "text",
                title: "Name",
                slot: entry
              }
            ]
          },
          %{}
        )

      form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

      html =
        render_component(&DynamicForm.Renderer.render/1,
          instance: %Instance{
            id: "slot-test",
            elements: [
              %Instance.Question{name: "name", type: "text", title: "Name", slot: entry}
            ]
          },
          form: form,
          components: CustomComponents
        )

      # Body renders, and the label comes from the built-in label/1 since
      # CustomComponents doesn't export one
      assert html =~ "CUSTOM CONTROL dynamic_form[name]"
      assert html =~ "Name"
    end
  end
end
