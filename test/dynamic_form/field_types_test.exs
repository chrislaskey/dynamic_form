defmodule DynamicForm.FieldTypesTest do
  # Not async: some tests set the :dynamic_form, :custom_field_types config
  use ExUnit.Case, async: false

  import Phoenix.LiveViewTest

  alias DynamicForm.Changeset
  alias DynamicForm.FieldTypes
  alias DynamicForm.Instance

  # A components module implementing one custom field type; select_with_search
  # has no clause here, exercising the input/1 catch-all degradation path
  defmodule FieldComponents do
    use Phoenix.Component

    def input(%{type: "multiselect"} = assigns) do
      selected = assigns.field.value |> List.wrap() |> Enum.map(&to_string/1)
      assigns = Phoenix.Component.assign(assigns, :selected, selected)

      ~H"""
      <div data-multiselect={@field.name}>
        <input type="hidden" name={"#{@field.name}[]"} value="" />
        <label :for={{text, value} <- @options}>
          <input
            type="checkbox"
            name={"#{@field.name}[]"}
            value={value}
            checked={to_string(value) in @selected}
          />
          {text}
        </label>
      </div>
      """
    end

    def input(assigns), do: DynamicForm.CoreComponents.input(assigns)
  end

  @field_types %{"multiselect" => {:array, :string}, "select_with_search" => :string}

  @instance %Instance{
    id: "field-types-test",
    elements: [
      %Instance.Question{
        name: "days",
        type: "multiselect",
        title: "Days",
        isRequired: true,
        choices: ["mon", "tue", "wed"]
      },
      %Instance.Question{
        name: "school",
        type: "select_with_search",
        title: "School",
        choices: ["north", "south"]
      }
    ]
  }

  describe "resolve/1" do
    test "merges per-form entries over the application config" do
      Application.put_env(:dynamic_form, :custom_field_types, %{
        "multiselect" => {:array, :string},
        "shared" => :string
      })

      on_exit(fn -> Application.delete_env(:dynamic_form, :custom_field_types) end)

      assert FieldTypes.resolve(%{"shared" => :integer, "extra" => :string}) == %{
               "multiselect" => {:array, :string},
               "shared" => :integer,
               "extra" => :string
             }
    end

    test "resolves to an empty map without config or per-form value" do
      assert FieldTypes.resolve(nil) == %{}
    end

    test "raises when a name collides with a built-in type" do
      assert_raise ArgumentError, ~r/collides with a built-in type/, fn ->
        FieldTypes.resolve(%{"dropdown" => :string})
      end
    end

    test "raises on invalid Ecto types and malformed maps" do
      assert_raise ArgumentError, ~r/invalid Ecto type/, fn ->
        FieldTypes.resolve(%{"multiselect" => "array"})
      end

      assert_raise ArgumentError, ~r/must be a map/, fn ->
        FieldTypes.resolve([{"multiselect", :string}])
      end
    end
  end

  describe "casting" do
    test "custom types cast as their declared Ecto type" do
      changeset =
        Changeset.create_changeset(
          @instance,
          %{"days" => ["mon", "tue"], "school" => "north"},
          custom_field_types: @field_types
        )

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :days) == ["mon", "tue"]
      assert Ecto.Changeset.get_change(changeset, :school) == "north"
    end

    test "array custom types get hidden-input normalization and required validation" do
      # The hidden "" entry is stripped from a real selection
      changeset =
        Changeset.create_changeset(@instance, %{"days" => ["", "mon"]},
          custom_field_types: @field_types
        )

      assert Ecto.Changeset.get_change(changeset, :days) == ["mon"]

      # An all-empty selection becomes nil so required fires
      changeset =
        Changeset.create_changeset(@instance, %{"days" => [""]}, custom_field_types: @field_types)

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:days]
    end

    test "without registration an array submission fails the string cast" do
      changeset = Changeset.create_changeset(@instance, %{"days" => ["mon"]})

      refute changeset.valid?
      assert {"is invalid", _} = changeset.errors[:days]
    end
  end

  describe "rendering" do
    defp render_form(instance, field_types) do
      changeset = Changeset.create_changeset(instance, %{}, custom_field_types: field_types)
      form = Phoenix.Component.to_form(changeset, as: "dynamic_form")

      render_component(&DynamicForm.Renderer.render/1,
        instance: instance,
        form: form,
        components: FieldComponents,
        custom_field_types: field_types
      )
    end

    test "registered types dispatch to the components module's input/1" do
      html = render_form(@instance, @field_types)

      assert html =~ ~s(data-multiselect="dynamic_form[days]")
      assert html =~ ~s(name="dynamic_form[days][]")
    end

    test "registered types without a matching clause fall to the input catch-all" do
      html = render_form(@instance, @field_types)

      # select_with_search has no clause in FieldComponents; the catch-all
      # renders it as a plain input carrying the type through
      assert html =~ ~s(type="select_with_search")
      assert html =~ ~s(name="dynamic_form[school]")
    end

    test "unregistered question types render nothing" do
      html = render_form(@instance, %{"multiselect" => {:array, :string}})

      refute html =~ "select_with_search"
      refute html =~ ~s(name="dynamic_form[school]")
    end
  end

  describe "declarative mode" do
    test "slot fields accept registered custom types" do
      field = %{
        __slot__: :field,
        inner_block: nil,
        type: "multiselect",
        name: "days",
        label: "Days",
        required: true,
        options: [{"Monday", "mon"}, {"Tuesday", "tue"}]
      }

      instance =
        Instance.FromSlots.convert!(%{
          id: "slots-test",
          field: [field],
          group: [],
          custom_field_types: @field_types
        })

      assert [%Instance.Question{type: "multiselect", name: "days", isRequired: true} = question] =
               instance.elements

      assert question.choices == [{"Monday", "mon"}, {"Tuesday", "tue"}]
    end

    test "slot fields with unregistered types raise" do
      field = %{__slot__: :field, inner_block: nil, type: "multiselect", name: "days"}

      assert_raise ArgumentError, ~r/unknown type "multiselect".*custom field type/s, fn ->
        Instance.FromSlots.convert!(%{id: "slots-test", field: [field], group: []})
      end
    end
  end
end
