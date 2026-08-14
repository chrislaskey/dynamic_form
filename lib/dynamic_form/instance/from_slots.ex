defmodule DynamicForm.Instance.FromSlots do
  @moduledoc """
  Converts `<:field>`, `<:group>`, and `<:nested>` slot entries from
  `DynamicForm.form/1` into a `DynamicForm.Instance` struct.

  This is the slot-mode counterpart to `DynamicForm.Instance.Decoder`: the
  decoder normalizes untrusted external data (JSON, string-keyed maps), while
  this module normalizes compiler-produced slot entries (atom-keyed maps).
  Both produce the same `%Instance{}` structs consumed by the rest of the
  library.

  ## Conversion rules

    * `<:field>` entries convert in template order — question types
      (#{inspect(~w(text comment dropdown radiogroup checkbox boolean rating tagbox file))})
      become `Instance.Question` structs; `html`, `image`, and `custom` become
      `Instance.Element` structs.
    * Snake_case slot attrs map to the SurveyJS-style struct fields
      (`visible_if` → `visibleIf`, `label` → `title`, `options` → `choices`, ...).
    * Flattened validation attrs (`min_length`, `max_length`, `min`, `max`,
      `pattern`, `format`) build `Instance.Validator` structs; the
      `validators` attr accepts explicit `%Validator{}` structs or atom-keyed
      maps for anything the flattened attrs can't express.
    * A field with `group="name"` is collected into a `panel` element declared
      by a `<:group name="name">` entry. The panel is emitted at the position
      of its first member field.
    * A field with `nested="name"` is collected into the `templateElements`
      of a `paneldynamic` question declared by a `<:nested name="name">`
      entry. `nested` declares the field's *data scope* (its value lives
      inside each entry of the nested form's list value); `group` declares
      visual grouping *within* that scope — the two combine, and a group
      inside a nested form declares the same `nested` scope on its own
      declaration. See the Nested Forms guide.
    * An entry with a slot body keeps the raw slot entry in the struct's
      `:slot` field so `DynamicForm.Renderer` can `render_slot/2` it. Bodies
      are in-memory only — they are dropped when the instance is JSON-encoded.

  ## Naming and scoping

  Field and `<:nested>` names are data keys, unique *per scope* (the form
  level is one scope; each nested form's template is another) — so a
  top-level `name` and an `addresses[].name` coexist, mirroring the
  application's schema. `<:group>` and `<:nested>` *declaration* names are
  reference targets for the flat `group=`/`nested=` attrs, so declarations
  are globally unique.

  ## Validation

  `convert!/1` raises `ArgumentError` with a descriptive message for invalid
  definitions: missing names, duplicate names within a scope, unknown types,
  choice questions without options, `custom` fields without a body,
  references to undeclared groups or nested forms, group/member nested-scope
  mismatches, nested forms with no members, and cyclic nested references.
  """

  alias DynamicForm.Instance

  @question_types ~w(text comment dropdown radiogroup checkbox boolean rating tagbox file)
  @element_types ~w(html image custom)
  @choice_types ~w(dropdown radiogroup checkbox tagbox)

  @doc """
  Validates slot entries and builds a `%DynamicForm.Instance{}`.

  Expects the assigns of `DynamicForm.form/1`: `:id` plus the `:field`,
  `:group`, and `:nested` slot lists (and optional `:title` and
  `:description`).
  """
  def convert!(assigns) do
    fields = Map.get(assigns, :field, [])
    groups = Map.get(assigns, :group, [])
    nesteds = Map.get(assigns, :nested, [])

    custom_types =
      assigns
      |> Map.get(:custom_field_types)
      |> DynamicForm.FieldTypes.resolve()
      |> Map.keys()

    validate!(fields, groups, nesteds, custom_types)

    slots = %{fields: Enum.with_index(fields), groups: groups, nesteds: nesteds}
    {elements, _anchor} = build_scope(nil, slots, custom_types)

    %Instance{
      id: assigns.id,
      title: assigns[:title],
      description: assigns[:description],
      elements: elements
    }
  end

  # Build the elements of one data scope (nil = the form level; otherwise a
  # <:nested> name). Each element carries an anchor — its first member
  # field's position in the flat <:field> list — and siblings sort by anchor,
  # so ungrouped fields keep their template order and containers render at
  # the position of their first member. Returns {elements, scope_anchor}.
  defp build_scope(scope, slots, custom_types) do
    field_items =
      for {entry, index} <- slots.fields, entry[:nested] == scope, entry[:group] == nil do
        {index, to_struct(entry, index, custom_types)}
      end

    nested_items =
      for entry <- slots.nesteds, entry[:nested] == scope, entry[:group] == nil do
        build_nested(entry, slots, custom_types)
      end

    group_items =
      for entry <- slots.groups, entry[:nested] == scope do
        build_group(entry, slots, custom_types)
      end
      |> Enum.reject(&is_nil/1)

    sorted = Enum.sort_by(field_items ++ nested_items ++ group_items, &elem(&1, 0))

    {Enum.map(sorted, &elem(&1, 1)), scope_anchor(sorted)}
  end

  # A nested declaration becomes a paneldynamic question; its scope's
  # elements become the template. Anchored at its first member field.
  defp build_nested(entry, slots, custom_types) do
    {template, anchor} = build_scope(entry.name, slots, custom_types)
    {anchor, nested_question(entry, template)}
  end

  # A group's members are the fields (and nested declarations) referencing
  # it; scope agreement is already validated, so membership needs no scope
  # filter. Memberless groups emit nothing.
  defp build_group(entry, slots, custom_types) do
    field_members =
      for {field, index} <- slots.fields, field[:group] == entry.name do
        {index, to_struct(field, index, custom_types)}
      end

    nested_members =
      for nested <- slots.nesteds, nested[:group] == entry.name do
        build_nested(nested, slots, custom_types)
      end

    case Enum.sort_by(field_members ++ nested_members, &elem(&1, 0)) do
      [] ->
        nil

      [{anchor, _} | _] = members ->
        {anchor, build_panel(entry, Enum.map(members, &elem(&1, 1)))}
    end
  end

  defp scope_anchor([]), do: nil
  defp scope_anchor([{anchor, _} | _]), do: anchor

  defp build_panel(group_def, members) do
    %Instance.Element{
      name: group_def.name,
      type: "panel",
      title: group_def[:title],
      visibleIf: group_def[:visible_if],
      enableIf: group_def[:enable_if],
      elements: members
    }
  end

  defp nested_question(entry, template) do
    %Instance.Question{
      name: entry.name,
      type: "paneldynamic",
      title: entry[:title],
      description: entry[:description],
      templateElements: template,
      templateTitle: entry[:entry_title],
      panelCount: entry[:entries],
      minPanelCount: entry[:min_entries],
      maxPanelCount: entry[:max_entries],
      addPanelText: entry[:add_text],
      removePanelText: entry[:remove_text],
      noEntriesText: entry[:no_entries_text],
      confirmDelete: entry[:confirm_delete],
      confirmDeleteText: entry[:confirm_text],
      keyName: entry[:key],
      keyDuplicationError: entry[:key_error],
      defaultValue: entry[:default],
      defaultPanelValue: entry[:default_entry],
      generateIds: entry[:generate_ids],
      isRequired: entry[:required],
      visibleIf: entry[:visible_if],
      enableIf: entry[:enable_if]
    }
  end

  defp to_struct(%{type: type} = entry, index, custom_types) do
    cond do
      type in @question_types or type in custom_types -> question_struct(entry, type)
      type in @element_types -> element_struct(entry, type, index)
    end
  end

  defp question_struct(entry, type) do
    %Instance.Question{
      name: entry.name,
      type: type,
      inputType: entry[:input_type],
      title: entry[:label],
      placeholder: entry[:placeholder],
      description: entry[:description],
      defaultValue: entry[:default],
      choices: entry[:options],
      validators: build_validators(entry),
      isRequired: entry[:required],
      requiredIf: entry[:required_if],
      readOnly: entry[:read_only],
      enableIf: entry[:enable_if],
      visibleIf: entry[:visible_if],
      rateMin: entry[:rate_min],
      rateMax: entry[:rate_max],
      rateStep: entry[:rate_step],
      metadata: entry[:metadata],
      slot: slot_ref(entry)
    }
  end

  defp element_struct(entry, type, index) do
    base = %Instance.Element{
      name: entry[:name] || "element-#{index + 1}",
      type: type,
      visibleIf: entry[:visible_if],
      enableIf: entry[:enable_if],
      metadata: entry[:metadata],
      slot: slot_ref(entry)
    }

    case type do
      "html" ->
        %{base | html: entry[:html]}

      "image" ->
        %{
          base
          | title: entry[:label],
            imageLink: entry[:src],
            imageWidth: entry[:width],
            imageHeight: entry[:height],
            imageFit: entry[:fit]
        }

      "custom" ->
        base
    end
  end

  # Keep the raw slot entry only when it has a body; a nil :slot means the
  # renderer uses its default rendering for the type.
  defp slot_ref(entry) do
    if entry[:inner_block], do: entry, else: nil
  end

  # Validators - flattened attrs plus the explicit :validators escape hatch

  defp build_validators(entry) do
    explicit =
      entry |> Map.get(:validators, nil) |> List.wrap() |> Enum.map(&normalize_validator/1)

    flattened =
      format_validator(entry) ++
        length_validator(entry) ++ numeric_validator(entry) ++ pattern_validator(entry)

    case explicit ++ flattened do
      [] -> nil
      validators -> validators
    end
  end

  defp normalize_validator(%Instance.Validator{} = validator), do: validator

  defp normalize_validator(map) when is_map(map) do
    %Instance.Validator{
      type: fetch_validator_type!(map),
      minLength: map[:minLength] || map[:min_length],
      maxLength: map[:maxLength] || map[:max_length],
      minValue: map[:minValue] || map[:min_value],
      maxValue: map[:maxValue] || map[:max_value],
      regex: map[:regex],
      text: map[:text]
    }
  end

  defp normalize_validator(other) do
    raise ArgumentError,
          "invalid entry in :validators — expected a %DynamicForm.Instance.Validator{} " <>
            "struct or a map with a :type key, got: #{inspect(other)}"
  end

  defp fetch_validator_type!(map) do
    map[:type] ||
      raise(ArgumentError, "validator map is missing a :type key: #{inspect(map)}")
  end

  defp format_validator(%{format: "email"}), do: [%Instance.Validator{type: "email"}]

  defp format_validator(%{format: other}) do
    raise ArgumentError,
          "unknown format #{inspect(other)} — supported formats: \"email\". " <>
            "Use the pattern attr or the :validators escape hatch for anything else."
  end

  defp format_validator(_entry), do: []

  defp length_validator(entry) do
    case {entry[:min_length], entry[:max_length]} do
      {nil, nil} -> []
      {min, max} -> [%Instance.Validator{type: "text", minLength: min, maxLength: max}]
    end
  end

  defp numeric_validator(entry) do
    case {entry[:min], entry[:max]} do
      {nil, nil} -> []
      {min, max} -> [%Instance.Validator{type: "numeric", minValue: min, maxValue: max}]
    end
  end

  defp pattern_validator(entry) do
    case entry[:pattern] do
      nil -> []
      pattern -> [%Instance.Validator{type: "regex", regex: pattern}]
    end
  end

  # Validation

  defp validate!(fields, groups, nesteds, custom_types) do
    validate_group_defs!(groups)
    validate_nested_defs!(nesteds)
    Enum.each(fields, &validate_field!(&1, custom_types))
    validate_refs!(fields, groups, nesteds)
    validate_scope_agreement!(fields, groups, nesteds)
    validate_cycles!(nesteds)
    validate_unique_names!(fields, groups, nesteds)
    validate_nested_members!(fields, nesteds)
  end

  defp validate_field!(entry, custom_types) do
    type = fetch_type!(entry, custom_types)
    validate_question_name!(type, entry, custom_types)
    validate_type_requirements!(type, entry)
  end

  defp fetch_type!(entry, custom_types) do
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
    if empty_options?(entry) do
      raise ArgumentError,
            "<:field type=\"#{type}\" name=\"#{entry[:name]}\"> requires an options list, " <>
              "e.g. options={[{\"Label\", \"value\"}, ...]}"
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

    Enum.each(groups, &validate_ref!(&1, "<:group", :nested, nested_names))

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

    for entry <- fields ++ nesteds, group_name = entry[:group] do
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

  # Nested declarations reference their parent scope by name; the reference
  # graph must be acyclic (and a nested form cannot contain itself).
  defp validate_cycles!(nesteds) do
    parents = Map.new(nesteds, &{&1.name, &1[:nested]})

    Enum.each(nesteds, fn nested ->
      walk_parents!(nested.name, parents[nested.name], parents, [nested.name])
    end)
  end

  defp walk_parents!(_start, nil, _parents, _path), do: :ok

  defp walk_parents!(start, start, _parents, path) do
    raise ArgumentError,
          "cyclic <:nested> references: #{Enum.join(Enum.reverse([start | path]), " -> ")}"
  end

  defp walk_parents!(start, current, parents, path) do
    walk_parents!(start, parents[current], parents, [current | path])
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
