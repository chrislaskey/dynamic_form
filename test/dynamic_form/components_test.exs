defmodule DynamicForm.ComponentsTest do
  # Not async: some tests set the :dynamic_form, :components application config
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias DynamicForm.{Components, Instance}

  # A partial components module: owns input/1, button/1, and
  # translate_error/1; everything else (radio groups, labels, errors,
  # groups) must fall back to the built-ins.
  defmodule CustomComponents do
    use Phoenix.Component

    def input(assigns) do
      ~H"""
      <div data-custom-input={@field.name}>
        <input type={@type} name={@field.name} id={@field.id} value={@field.value} />
      </div>
      """
    end

    # Mirrors a Phoenix-generated button/1: declares a global `rest` and
    # splats it, so event attributes the renderer forwards survive
    attr(:type, :string, default: nil)
    attr(:disabled, :boolean, default: false)
    attr(:rest, :global)
    slot(:inner_block, required: true)

    def button(assigns) do
      ~H"""
      <button data-custom-button type={@type} disabled={@disabled} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end

    def translate_error({msg, _opts}), do: "custom: " <> msg

    def nested_entry(assigns) do
      ~H"""
      <div data-custom-nested-entry={@index} data-nested-name={@name}>
        {render_slot(@inner_block)}
      </div>
      """
    end

    def dynamic_form_group(%{type: "cards"} = assigns) do
      ~H"""
      <div data-custom-cards={@name}>{render_slot(@inner_block)}</div>
      """
    end

    def dynamic_form_group(assigns) do
      ~H"""
      <div
        data-custom-group={@title}
        data-group-name={@name}
        data-group-type={@type}
        data-group-disabled={to_string(@disabled)}
      >
        {render_slot(@inner_block)}
      </div>
      """
    end
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
      refute html =~ ~s(class="phx-submit-loading:opacity-75 btn btn-primary")
    end

    test "without a components module everything renders built-in" do
      html = render_form()

      refute html =~ "data-custom"
      assert html =~ ~s(class="phx-submit-loading:opacity-75 btn btn-primary")
    end

    test "nested_entry wraps each repeating entry, keeping the entry contents" do
      instance = %Instance{
        id: "nested-entry-test",
        elements: [
          %Instance.Question{
            name: "addresses",
            type: "paneldynamic",
            title: "Addresses",
            templateElements: [
              %Instance.Question{name: "street", type: "text", title: "Street"}
            ]
          }
        ]
      }

      params = %{"addresses" => [%{"street" => "110 Main St"}, %{"street" => "13 Dearborn"}]}
      changeset = DynamicForm.Changeset.create_changeset(instance, params)
      form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

      render = fn overrides ->
        render_component(
          &DynamicForm.form/1,
          Keyword.merge(
            [id: "nested-entry-test", render_only: true, instance: instance, form: form],
            overrides
          )
        )
      end

      # Delegated: the custom container replaces the built-in one per entry,
      # with the entry contents (fields, remove button) rendered inside it
      html = render.(components: CustomComponents)

      assert html =~ ~s(data-custom-nested-entry="0")
      assert html =~ ~s(data-custom-nested-entry="1")
      assert html =~ ~s(data-nested-name="addresses")
      assert html =~ ~s(name="dynamic_form[addresses][0][street]")
      assert html =~ ~s(phx-click="remove_nested_entry")
      refute html =~ "mt-3 rounded-lg border border-gray-200 p-4"

      # Fallback: the built-in container renders the default classes
      html = render.([])

      assert html =~ "mt-3 rounded-lg border border-gray-200 p-4"
      refute html =~ "data-custom-nested-entry"
    end

    test "dynamic_form_group wraps a group, keeping the members inside it" do
      instance = %Instance{
        id: "group-test",
        elements: [
          %Instance.Element{
            name: "address",
            type: "panel",
            title: "Shipping Address",
            elements: [
              %Instance.Question{name: "street", type: "text", title: "Street"}
            ]
          }
        ]
      }

      changeset = DynamicForm.Changeset.create_changeset(instance, %{})
      form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

      render = fn overrides ->
        render_component(
          &DynamicForm.form/1,
          Keyword.merge(
            [id: "group-test", render_only: true, instance: instance, form: form],
            overrides
          )
        )
      end

      # Delegated: the custom container replaces the built-in card, with the
      # group's members rendered inside it
      html = render.(components: CustomComponents)

      assert html =~ ~s(data-custom-group="Shipping Address")
      assert html =~ ~s(name="dynamic_form[street]")
      refute html =~ "text-lg font-semibold text-gray-900 mb-4"

      # The group's identity and layout come through, so one override can
      # treat two groups differently
      assert html =~ ~s(data-group-name="address")
      assert html =~ ~s(data-group-type="horizontal")

      # Fallback: the built-in renders its own heading and member layout
      html = render.([])

      assert html =~ "text-lg font-semibold text-gray-900 mb-4"
      refute html =~ "data-custom-group"
    end

    test "a nested form's add button renders through button/1" do
      instance = %Instance{
        id: "add-button-test",
        elements: [
          %Instance.Question{
            name: "addresses",
            type: "paneldynamic",
            title: "Addresses",
            addPanelText: "Add address",
            templateElements: [%Instance.Question{name: "street", type: "text"}]
          }
        ]
      }

      render = fn overrides ->
        changeset = DynamicForm.Changeset.create_changeset(instance, %{})

        render_component(
          &DynamicForm.form/1,
          Keyword.merge(
            [
              id: "add-button-test",
              render_only: true,
              instance: instance,
              form: Phoenix.Component.to_form(changeset, as: "dynamic_form")
            ],
            overrides
          )
        )
      end

      # Delegated: the app's button renders it, still carrying the event
      # attributes that make it work
      html = render.(components: CustomComponents)

      assert html =~ "data-custom-button"
      assert html =~ ~s(phx-click="add_nested_entry")
      assert html =~ ~s(phx-value-path="addresses")
      assert html =~ "Add address"

      # Fallback: the built-in button's classes, not a bare button
      html = render.([])

      refute html =~ "data-custom-button"
      assert html =~ ~s(phx-click="add_nested_entry")
      assert html =~ "btn"
    end

    test "a components module can define its own group type" do
      instance = %Instance{
        id: "group-type-test",
        elements: [
          %Instance.Element{
            name: "plans",
            type: "panel",
            groupType: "cards",
            elements: [%Instance.Question{name: "plan", type: "text", title: "Plan"}]
          }
        ]
      }

      changeset = DynamicForm.Changeset.create_changeset(instance, %{})

      html =
        render_component(&DynamicForm.form/1,
          id: "group-type-test",
          render_only: true,
          instance: instance,
          form: Phoenix.Component.to_form(changeset, as: "dynamic_form"),
          components: CustomComponents
        )

      assert html =~ ~s(data-custom-cards="plans")
    end

    test "a group disabled by enable_if reports it to the override" do
      instance = %Instance{
        id: "group-disabled-test",
        elements: [
          %Instance.Question{name: "toggle", type: "boolean", title: "Toggle"},
          %Instance.Element{
            name: "extras",
            type: "panel",
            enableIf: "{toggle} = true",
            elements: [%Instance.Question{name: "note", type: "text", title: "Note"}]
          }
        ]
      }

      render = fn params ->
        changeset = DynamicForm.Changeset.create_changeset(instance, params)

        render_component(&DynamicForm.form/1,
          id: "group-disabled-test",
          render_only: true,
          instance: instance,
          form: Phoenix.Component.to_form(changeset, as: "dynamic_form"),
          components: CustomComponents
        )
      end

      assert render.(%{"toggle" => false}) =~ ~s(data-group-disabled="true")
      refute render.(%{"toggle" => true}) =~ ~s(data-group-disabled="true")
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
