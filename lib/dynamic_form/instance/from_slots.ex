defmodule DynamicForm.Instance.FromSlots do
  @moduledoc """
  Converts `<:field>` and `<:group>` slot entries from `DynamicForm.form/1`
  into a `DynamicForm.Instance` struct.

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
    * An entry with a slot body keeps the raw slot entry in the struct's
      `:slot` field so `DynamicForm.Renderer` can `render_slot/2` it. Bodies
      are in-memory only — they are dropped when the instance is JSON-encoded.

  ## Validation

  `convert!/1` raises `ArgumentError` with a descriptive message for invalid
  definitions: missing names, duplicate names, unknown types, choice questions
  without options, `custom` fields without a body, or fields referencing
  undeclared groups.
  """

  alias DynamicForm.Instance

  @question_types ~w(text comment dropdown radiogroup checkbox boolean rating tagbox file)
  @element_types ~w(html image custom)
  @choice_types ~w(dropdown radiogroup checkbox tagbox)

  @doc """
  Validates slot entries and builds a `%DynamicForm.Instance{}`.

  Expects the assigns of `DynamicForm.form/1`: `:id` plus the `:field` and
  `:group` slot lists (and optional `:title` and `:description`).
  """
  def convert!(assigns) do
    fields = Map.get(assigns, :field, [])
    groups = Map.get(assigns, :group, [])

    custom_types =
      assigns
      |> Map.get(:custom_field_types)
      |> DynamicForm.FieldTypes.resolve()
      |> Map.keys()

    validate!(fields, groups, custom_types)

    group_defs = Map.new(groups, &{&1.name, &1})

    converted =
      fields
      |> Enum.with_index()
      |> Enum.map(fn {entry, index} -> {entry[:group], to_struct(entry, index, custom_types)} end)

    %Instance{
      id: assigns.id,
      title: assigns[:title],
      description: assigns[:description],
      elements: position_groups(converted, group_defs)
    }
  end

  # Emit ungrouped elements in order; emit each group's panel (containing all
  # of its members) at the position of the group's first member.
  defp position_groups(converted, group_defs) do
    {elements, _seen} =
      Enum.reduce(converted, {[], MapSet.new()}, fn
        {nil, element}, {acc, seen} ->
          {[element | acc], seen}

        {group_name, _element}, {acc, seen} ->
          if MapSet.member?(seen, group_name) do
            {acc, seen}
          else
            members = for {^group_name, element} <- converted, do: element
            panel = build_panel(Map.fetch!(group_defs, group_name), members)
            {[panel | acc], MapSet.put(seen, group_name)}
          end
      end)

    Enum.reverse(elements)
  end

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

  defp validate!(fields, groups, custom_types) do
    validate_group_defs!(groups)
    Enum.each(fields, &validate_field!(&1, custom_types))
    validate_unique_names!(fields, groups)
    validate_group_refs!(fields, groups)
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
  end

  defp validate_unique_names!(fields, groups) do
    names =
      Enum.map(fields, fn entry -> entry[:name] end) ++
        Enum.map(groups, fn group -> group[:name] end)

    duplicates =
      names
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(fn {name, _count} -> name end)

    if duplicates != [] do
      raise ArgumentError,
            "duplicate names across <:field> and <:group> entries: " <>
              Enum.join(Enum.sort(duplicates), ", ")
    end
  end

  defp validate_group_refs!(fields, groups) do
    declared = MapSet.new(groups, & &1.name)
    Enum.each(fields, &validate_group_ref!(&1, declared))
  end

  defp validate_group_ref!(entry, declared) do
    group_name = entry[:group]

    if group_name && not MapSet.member?(declared, group_name) do
      raise ArgumentError,
            "<:field name=\"#{entry[:name]}\"> references group #{inspect(group_name)} " <>
              "but no <:group name=\"#{group_name}\"> is declared"
    end
  end

  defp describe_entry(entry) do
    case entry[:name] do
      nil -> "(entry #{inspect(Map.drop(entry, [:__slot__, :inner_block]))})"
      name -> "(name: #{inspect(name)})"
    end
  end
end
