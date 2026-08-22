defmodule DynamicForm.Helpers.FormTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [to_form: 2]

  alias DynamicForm.Helpers

  defp changeset(params) do
    Ecto.Changeset.cast({%{}, %{name: :string, email: :string}}, params, [:name, :email])
  end

  describe "get_params/1" do
    test "returns the changeset's changes" do
      form = to_form(changeset(%{"name" => "Ada"}), as: "f")

      assert Helpers.Form.get_params(form) == %{name: "Ada"}
    end

    test "returns an empty map when the source has no changes field" do
      form = to_form(%{"name" => "Ada"}, as: "f")

      assert Helpers.Form.get_params(form) == %{}
    end
  end

  describe "get_applied_data/1" do
    test "applies a changeset-backed form's changes" do
      form = to_form(changeset(%{"name" => "Ada"}), as: "f")

      assert Helpers.Form.get_applied_data(form) == %{name: "Ada"}
    end

    test "falls back to params for a non-changeset form" do
      form = to_form(%{"name" => "Ada"}, as: "f")

      assert Helpers.Form.get_applied_data(form) == %{"name" => "Ada"}
    end
  end

  describe "put_data/2" do
    test "stashes data in a form's options under :form_data" do
      form = Helpers.Form.put_data(to_form(%{}, as: "f"), %{name: "Ada"})

      assert form.options[:form_data] == %{name: "Ada"}
    end

    test "decorates a field's enclosing form" do
      form = to_form(changeset(%{"name" => "Ada"}), as: "f")
      field = Helpers.Form.put_data(form[:name], %{name: "Ada"})

      assert %Phoenix.HTML.FormField{} = field
      assert field.form.options[:form_data] == %{name: "Ada"}
    end
  end
end
