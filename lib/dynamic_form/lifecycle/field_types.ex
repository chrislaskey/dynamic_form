defmodule DynamicForm.FieldTypes do
  @moduledoc """
  Resolution for custom field types.

  Applications can extend the built-in question types with their own,
  declared as a map of type name to the Ecto type the field casts as —
  globally:

      config :dynamic_form,
        custom_field_types: %{
          "multiselect" => {:array, :string},
          "select_with_search" => :string
        }

  or per form (per-form entries merge over — and win against — the config):

      <DynamicForm.form
        id="signup"
        custom_field_types={%{"multiselect" => {:array, :string}}}
      >

  The map does triple duty:

    * its **keys are the vocabulary** — `<:field type="multiselect">` (or
      `"type": "multiselect"` in data mode) is accepted anywhere a built-in
      type is; question types in neither the built-ins nor the map are
      skipped by the renderer (nothing renders — obvious in testing, not
      broken-looking in production)
    * its **values drive casting** — the changeset casts the field as the
      declared Ecto type, and `{:array, _}` types get the same hidden-input
      normalization as the built-in checkbox/tagbox groups, so `required`
      works
    * **rendering dispatches to the components module** — define a matching
      `input/1` clause (see `DynamicForm.ComponentResolver`):

          def input(%{type: "multiselect"} = assigns) do
            ~H\"\"\"
            ...
            \"\"\"
          end

  Validation beyond casting and `required` is the application's job — use
  the `validators` attribute or the `on_change`/`on_submit` lifecycle
  callbacks.

  Custom type names may not collide with built-in question or element types;
  collisions and malformed maps raise.
  """

  @builtin_question_types ~w(text comment dropdown radiogroup checkbox boolean rating tagbox file paneldynamic)
  @builtin_element_types ~w(html image panel custom)

  @doc "The built-in question type names."
  def builtin_question_types, do: @builtin_question_types

  @doc """
  Resolves the custom field types: the `:custom_field_types` application
  config merged with the per-form map, per-form entries winning.

  Raises `ArgumentError` on malformed maps or names colliding with built-in
  types.
  """
  def resolve(per_form \\ nil) do
    global = Application.get_env(:dynamic_form, :custom_field_types) || %{}

    Map.merge(
      validate!(global, "config :dynamic_form, :custom_field_types"),
      validate!(per_form || %{}, "the custom_field_types attribute")
    )
  end

  @doc "Whether `type` is a registered custom field type."
  def custom?(field_types, type) when is_map(field_types), do: is_map_key(field_types, type)

  @doc "Whether `type` is a registered custom field type casting as an array."
  def array?(field_types, type) when is_map(field_types) do
    match?({:array, _}, Map.get(field_types, type))
  end

  defp validate!(map, source) when is_map(map) do
    Enum.each(map, fn {name, ecto_type} ->
      validate_name!(name, source)
      validate_ecto_type!(name, ecto_type, source)
    end)

    map
  end

  defp validate!(other, source) do
    raise ArgumentError,
          "#{source} must be a map of type name to Ecto type, " <>
            ~s|e.g. %{"multiselect" => {:array, :string}}, got: #{inspect(other)}|
  end

  defp validate_name!(name, source) do
    cond do
      not is_binary(name) or name == "" ->
        raise ArgumentError,
              "custom field type names must be non-empty strings, " <>
                "got #{inspect(name)} in #{source}"

      name in @builtin_question_types or name in @builtin_element_types ->
        raise ArgumentError,
              "custom field type #{inspect(name)} in #{source} collides with a " <>
                "built-in type — built-in types cannot be overridden"

      true ->
        :ok
    end
  end

  defp validate_ecto_type!(name, ecto_type, source) do
    if valid_ecto_type?(ecto_type) do
      :ok
    else
      raise ArgumentError,
            "custom field type #{inspect(name)} in #{source} has an invalid Ecto " <>
              "type: #{inspect(ecto_type)} — expected an atom like :string or " <>
              "{:array, :string}"
    end
  end

  defp valid_ecto_type?({:array, inner}), do: valid_ecto_type?(inner)
  defp valid_ecto_type?(type) when is_atom(type), do: true
  defp valid_ecto_type?(_type), do: false
end
