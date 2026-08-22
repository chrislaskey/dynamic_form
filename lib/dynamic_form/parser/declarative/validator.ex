defmodule DynamicForm.Parser.Declarative.Validator do
  @moduledoc """
  Validates the slot declarations handed to `DynamicForm.form/1` before
  `DynamicForm.Parser.Declarative` builds an `Instance` from them, raising
  `ArgumentError` with a specific message for each definition mistake.

  Also owns the slot type vocabulary — the question and element type names a
  `<:field>` may declare.

  Internal module — not part of the public API.
  """

  @question_types ~w(text comment dropdown radiogroup checkbox boolean rating tagbox file)
  @element_types ~w(html image custom)
  @choice_types ~w(dropdown radiogroup checkbox tagbox)
  @choice_modes ~w(all selected unselected)

  @doc "The question type names a <:field> may declare."
  def question_types, do: @question_types

  @doc "The element type names a <:field> may declare."
  def element_types, do: @element_types

  @doc """
  Validates every slot declaration, raising on the first mistake found.
  """
  def validate!(fields, groups, nesteds, custom_types) do
    validate_group_defs!(groups)
    validate_nested_defs!(nesteds)
    Enum.each(fields, &validate_field!(&1, custom_types))
    validate_refs!(fields, groups, nesteds)
    validate_scope_agreement!(fields, groups, nesteds)
    validate_cycles!(nesteds, groups)
    validate_unique_names!(fields, groups, nesteds)
    validate_nested_members!(fields, nesteds)
    validate_carry_forward!(fields, nesteds)
  end

  # choices_from builds a field's choices from a <:nested> form's entries.
  defp validate_carry_forward!(fields, nesteds) do
    validate_carry_forward_cycles!(fields)

    Enum.each(fields, fn entry ->
      cond do
        entry[:choices_from] != nil -> validate_carry_forward_source!(entry, fields, nesteds)
        entry[:choice_value] != nil -> raise_carry_forward_orphan!(entry, "choice_value")
        entry[:choice_text] != nil -> raise_carry_forward_orphan!(entry, "choice_text")
        entry[:choices_mode] != nil -> raise_carry_forward_orphan!(entry, "choices_mode")
        true -> :ok
      end
    end)
  end

  defp raise_carry_forward_orphan!(entry, attr) do
    raise ArgumentError,
          "<:field name=\"#{entry[:name]}\"> received #{attr} without choices_from — " <>
            "#{attr} configures where carried-forward choices come from"
  end

  defp validate_carry_forward_source!(entry, fields, nesteds) do
    source = entry[:choices_from]

    if entry[:type] not in @choice_types do
      raise ArgumentError,
            "<:field type=\"#{entry[:type]}\" name=\"#{entry[:name]}\"> received " <>
              "choices_from, which only applies to choice fields: " <>
              "#{Enum.join(@choice_types, ", ")}"
    end

    candidates =
      Enum.filter(nesteds, &(&1[:name] == source)) ++
        Enum.filter(fields, &(&1[:name] == source and &1[:type] in @choice_types))

    in_scope = Enum.filter(candidates, &(&1[:nested] == entry[:nested]))
    at_form_level = Enum.filter(candidates, &(&1[:nested] == nil))

    if entry[:nested] != nil and in_scope != [] and at_form_level != [] do
      raise ArgumentError,
            "<:field name=\"#{entry[:name]}\"> choices_from=#{inspect(source)} is ambiguous: " <>
              "a question with that name exists both inside #{inspect(entry[:nested])} and " <>
              "at the form level. Rename one of them"
    end

    case in_scope ++ at_form_level do
      [] ->
        raise ArgumentError,
              "<:field name=\"#{entry[:name]}\"> choices_from=#{inspect(source)} does not " <>
                "match a <:nested> form or a choice field"

      [source_entry | _] ->
        validate_carry_forward_config!(entry, source_entry)
    end
  end

  # A nested source carries one choice per entry, so it needs to know which
  # fields label and identify them. A choice-typed source already has
  # {text, value} pairs, so those attrs have nothing to configure — but the
  # selected/unselected modes only make sense there.
  defp validate_carry_forward_config!(entry, %{__slot__: :nested} = nested) do
    if entry[:choice_text] == nil do
      raise ArgumentError,
            "<:field name=\"#{entry[:name]}\"> requires choice_text with choices_from — " <>
              "without it the choices would be labelled with their opaque ids. Name a field " <>
              ~s|of #{inspect(nested[:name])}, or interpolate several: choice_text="{min} - {max}"|
    end

    if entry[:choices_mode] != nil do
      raise ArgumentError,
            "<:field name=\"#{entry[:name]}\"> received choices_mode, which applies to " <>
              "choices carried forward from another choice field. " <>
              "#{inspect(nested[:name])} is a <:nested> form — every entry is a choice"
    end

    if nested[:generate_ids] == false and entry[:choice_value] == nil do
      raise ArgumentError,
            "<:field name=\"#{entry[:name]}\"> carries choices forward from " <>
              "#{inspect(nested[:name])}, which sets generate_ids={false} — so its entries " <>
              "have no stable id. Give the nested form ids, or name a value field with " <>
              "choice_value"
    end
  end

  defp validate_carry_forward_config!(entry, source) do
    Enum.each([:choice_text, :choice_value], fn attr ->
      if entry[attr] != nil do
        raise ArgumentError,
              "<:field name=\"#{entry[:name]}\"> received #{attr}, which applies to choices " <>
                "carried forward from a <:nested> form. #{inspect(source[:name])} is a choice " <>
                "field — its options already have a label and a value"
      end
    end)

    if entry[:choices_mode] not in [nil | @choice_modes] do
      raise ArgumentError,
            "<:field name=\"#{entry[:name]}\"> has choices_mode " <>
              "#{inspect(entry[:choices_mode])} — expected one of: " <>
              "#{Enum.join(@choice_modes, ", ")}"
    end
  end

  # A carries from B, B carries from A — reachable only between choice
  # fields, since a nested form's entries are never themselves carried.
  defp validate_carry_forward_cycles!(fields) do
    edges =
      for entry <- fields, entry[:choices_from] != nil, into: %{} do
        {entry[:name], entry[:choices_from]}
      end

    Enum.each(Map.keys(edges), &walk_carry_forward!(&1, edges, []))
  end

  defp walk_carry_forward!(name, edges, seen) do
    cond do
      name in seen ->
        raise ArgumentError,
              "<:field> choices_from references form a cycle: " <>
                Enum.join(Enum.reverse([name | seen]), " → ")

      Map.has_key?(edges, name) ->
        walk_carry_forward!(Map.fetch!(edges, name), edges, [name | seen])

      true ->
        :ok
    end
  end

  defp validate_field!(entry, custom_types) do
    type = get_type!(entry, custom_types)
    validate_question_name!(type, entry, custom_types)
    validate_type_requirements!(type, entry)
  end

  defp get_type!(entry, custom_types) do
    type = entry[:type]

    cond do
      type == nil ->
        raise ArgumentError,
              "<:field> requires a type attribute #{describe_entry(entry)}"

      type in @question_types or type in @element_types or type in custom_types ->
        type

      true ->
        raise ArgumentError,
              "<:field> has unknown type #{inspect(type)} #{describe_entry(entry)} — " <>
                "expected one of: #{Enum.join(@question_types ++ @element_types, ", ")}, " <>
                "or a registered custom field type (see DynamicForm.FieldTypes)"
    end
  end

  # Question types — built-in or custom — collect input, so they need a name
  defp validate_question_name!(type, entry, custom_types) do
    if (type in @question_types or type in custom_types) and
         (entry[:name] == nil or entry[:name] == "") do
      raise ArgumentError, "<:field type=\"#{type}\"> requires a name attribute"
    end

    :ok
  end

  defp validate_type_requirements!(type, entry) when type in @choice_types do
    # Options can come from the choices_from source or be rendered by a slot
    # body instead of an options list.
    if empty_options?(entry) and entry[:choices_from] == nil and entry[:inner_block] == nil do
      raise ArgumentError,
            "<:field type=\"#{type}\" name=\"#{entry[:name]}\"> requires an options list, " <>
              "a choices_from source, or a slot body rendering its own choices"
    end

    if not empty_options?(entry) and entry[:choices_from] != nil do
      raise ArgumentError,
            "<:field type=\"#{type}\" name=\"#{entry[:name]}\"> received both options and " <>
              "choices_from — a field's choices come from one or the other"
    end
  end

  defp validate_type_requirements!("custom", entry) do
    if entry[:inner_block] == nil do
      raise ArgumentError,
            "<:field type=\"custom\"> requires a slot body #{describe_entry(entry)}"
    end
  end

  defp validate_type_requirements!("html", entry) do
    case {entry[:inner_block], empty_html?(entry)} do
      {nil, true} ->
        raise ArgumentError,
              "<:field type=\"html\"> requires either an html attribute or a slot body " <>
                describe_entry(entry)

      {inner_block, false} when not is_nil(inner_block) ->
        raise ArgumentError,
              "<:field type=\"html\"> cannot have both an html attribute and a slot body " <>
                describe_entry(entry)

      _ ->
        :ok
    end
  end

  defp validate_type_requirements!("image", entry) do
    if entry[:src] == nil or entry[:src] == "" do
      raise ArgumentError,
            "<:field type=\"image\"> requires a src attribute #{describe_entry(entry)}"
    end
  end

  defp validate_type_requirements!("file", entry) do
    if entry[:nested] do
      raise ArgumentError,
            "<:field type=\"file\" name=\"#{entry[:name]}\"> cannot be nested — " <>
              "file uploads inside nested forms are not supported"
    end

    :ok
  end

  defp validate_type_requirements!(_type, _entry), do: :ok

  defp empty_options?(entry) do
    case entry[:options] do
      options when is_list(options) and options != [] -> false
      _ -> true
    end
  end

  defp empty_html?(entry), do: entry[:html] == nil or entry[:html] == ""

  defp validate_group_defs!(groups) do
    Enum.each(groups, fn group ->
      if group[:name] == nil or group[:name] == "" do
        raise ArgumentError, "<:group> requires a name attribute"
      end
    end)

    validate_unique_declarations!(groups, "<:group>")
  end

  defp validate_nested_defs!(nesteds) do
    Enum.each(nesteds, fn nested ->
      if nested[:name] == nil or nested[:name] == "" do
        raise ArgumentError, "<:nested> requires a name attribute"
      end
    end)

    validate_unique_declarations!(nesteds, "<:nested>")
  end

  # Group and nested declarations are reference targets for the flat
  # group=/nested= attrs, so their names are globally unique (field names,
  # by contrast, are unique per scope).
  defp validate_unique_declarations!(declarations, kind) do
    duplicates = duplicated(Enum.map(declarations, & &1[:name]))

    if duplicates != [] do
      raise ArgumentError,
            "duplicate #{kind} declarations: #{Enum.join(duplicates, ", ")} — " <>
              "#{kind} names are reference targets and must be unique across the form"
    end
  end

  defp validate_refs!(fields, groups, nesteds) do
    group_names = MapSet.new(groups, & &1.name)
    nested_names = MapSet.new(nesteds, & &1.name)

    Enum.each(fields, fn entry ->
      validate_ref!(entry, "<:field", :group, group_names)
      validate_ref!(entry, "<:field", :nested, nested_names)
    end)

    Enum.each(groups, fn entry ->
      validate_ref!(entry, "<:group", :nested, nested_names)
      validate_ref!(entry, "<:group", :group, group_names)
    end)

    Enum.each(nesteds, fn entry ->
      validate_ref!(entry, "<:nested", :group, group_names)
      validate_ref!(entry, "<:nested", :nested, nested_names)
    end)
  end

  defp validate_ref!(entry, kind, attr, declared) do
    ref = entry[attr]

    if ref && not MapSet.member?(declared, ref) do
      raise ArgumentError,
            "#{kind} name=\"#{entry[:name]}\"> references #{attr} #{inspect(ref)} " <>
              "but no <:#{attr} name=\"#{ref}\"> is declared"
    end
  end

  # Double-entry bookkeeping for placement: a group declares its nested
  # scope, and every member must declare the identical scope — an omission
  # or mismatch is an error instead of a silent data-shape change.
  defp validate_scope_agreement!(fields, groups, nesteds) do
    group_defs = Map.new(groups, &{&1.name, &1})

    # Groups are checked alongside fields and nested forms: a group inside
    # another group lives in the parent's scope, so it must declare the same
    # one. Otherwise a form-level panel could sit inside an entry-scoped one.
    for entry <- fields ++ nesteds ++ groups, group_name = entry[:group] do
      group_scope = Map.fetch!(group_defs, group_name)[:nested]
      member_scope = entry[:nested]

      if member_scope != group_scope do
        raise ArgumentError,
              "\"#{entry[:name]}\" is in group \"#{group_name}\" " <>
                "(#{describe_scope(group_scope)}) but declares #{describe_scope(member_scope)} — " <>
                "a group's members must declare the group's nested scope"
      end
    end

    :ok
  end

  defp describe_scope(nil), do: "no nested scope"
  defp describe_scope(scope), do: "nested scope \"#{scope}\""

  # Nested and group declarations reference their parent by name; both
  # reference graphs must be acyclic, and neither can contain itself.
  # Unchecked, a cycle recurses forever while building the elements.
  defp validate_cycles!(nesteds, groups) do
    walk_all!(nesteds, :nested, "<:nested>")
    walk_all!(groups, :group, "<:group>")
  end

  defp walk_all!(declarations, attr, kind) do
    parents = Map.new(declarations, &{&1.name, &1[attr]})

    Enum.each(declarations, fn declaration ->
      walk_parents!(
        declaration.name,
        parents[declaration.name],
        parents,
        [declaration.name],
        kind
      )
    end)
  end

  defp walk_parents!(_start, nil, _parents, _path, _kind), do: :ok

  defp walk_parents!(start, start, _parents, path, kind) do
    raise ArgumentError,
          "cyclic #{kind} references: #{Enum.join(Enum.reverse([start | path]), " -> ")}"
  end

  defp walk_parents!(start, current, parents, path, kind) do
    walk_parents!(start, parents[current], parents, [current | path], kind)
  end

  # Field and <:nested> names are data keys, unique per scope. A group's
  # name must also not collide with the data keys in its own scope — the
  # group renders as a named element alongside them.
  defp validate_unique_names!(fields, groups, nesteds) do
    entries =
      Enum.map(fields, &{&1[:nested], &1[:name]}) ++ Enum.map(nesteds, &{&1[:nested], &1.name})

    entries
    |> Enum.reject(fn {_scope, name} -> is_nil(name) end)
    |> Enum.group_by(fn {scope, _name} -> scope end, fn {_scope, name} -> name end)
    |> Enum.each(fn {scope, names} ->
      case duplicated(names) do
        [] ->
          :ok

        duplicates ->
          raise ArgumentError,
                "duplicate names in #{describe_scope_location(scope)}: " <>
                  Enum.join(duplicates, ", ") <>
                  " — names must be unique within their scope"
      end
    end)

    scope_names = entries |> Enum.reject(fn {_s, name} -> is_nil(name) end) |> MapSet.new()

    for group <- groups, MapSet.member?(scope_names, {group[:nested], group.name}) do
      raise ArgumentError,
            "<:group name=\"#{group.name}\"> collides with a field or nested form of the " <>
              "same name in #{describe_scope_location(group[:nested])}"
    end

    :ok
  end

  defp describe_scope_location(nil), do: "the top-level form"
  defp describe_scope_location(scope), do: "nested form \"#{scope}\""

  # A nested form with no members would render (and validate) an empty
  # template — always a definition mistake.
  defp validate_nested_members!(fields, nesteds) do
    member_scopes =
      MapSet.new(Enum.map(fields, & &1[:nested]) ++ Enum.map(nesteds, & &1[:nested]))

    Enum.each(nesteds, fn nested ->
      unless MapSet.member?(member_scopes, nested.name) do
        raise ArgumentError,
              "<:nested name=\"#{nested.name}\"> has no members — add fields with " <>
                "nested=\"#{nested.name}\""
      end
    end)
  end

  defp duplicated(names) do
    names
    |> Enum.frequencies()
    |> Enum.filter(fn {_name, count} -> count > 1 end)
    |> Enum.map(fn {name, _count} -> name end)
    |> Enum.sort()
  end

  defp describe_entry(entry) do
    case entry[:name] do
      nil -> "(entry #{inspect(Map.drop(entry, [:__slot__, :inner_block]))})"
      name -> "(name: #{inspect(name)})"
    end
  end
end
