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
      of its first member field. A `<:group>` can itself declare `group=` to
      sit inside another panel, and a parent takes the position of its
      earliest member — including one contributed by a child group.
    * A field with `nested="name"` is collected into the `templateElements`
      of a `paneldynamic` question declared by a `<:nested name="name">`
      entry. `nested` declares the field's *data scope* (its value lives
      inside each entry of the nested form's list value); `group` declares
      visual grouping *within* that scope — the two combine, and a group
      inside a nested form declares the same `nested` scope on its own
      declaration. See the Nested Forms guide.
    * An entry with a slot body keeps the raw slot entry in the struct's
      `:slot` field so `DynamicForm.Renderer.Component` can `render_slot/2` it. Bodies
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
  definitions — see `DynamicForm.Instance.FromSlots.Validator` for the full
  set of checks: missing names, duplicate names within a scope, unknown
  types, choice questions without options, `custom` fields without a body,
  references to undeclared groups or nested forms, group/member nested-scope
  mismatches, nested forms with no members, and cyclic `<:nested>` or
  `<:group>` references.
  """

  alias DynamicForm.Instance
  alias DynamicForm.Instance.FromSlots.Validator

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

    Validator.validate!(fields, groups, nesteds, custom_types)

    slots = %{fields: Enum.with_index(fields), groups: groups, nesteds: nesteds}
    {elements, _anchor} = create_scope(nil, slots, custom_types)

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
  defp create_scope(scope, slots, custom_types) do
    field_items =
      for {entry, index} <- slots.fields, entry[:nested] == scope, entry[:group] == nil do
        {index, to_struct(entry, index, custom_types)}
      end

    nested_items =
      for entry <- slots.nesteds, entry[:nested] == scope, entry[:group] == nil do
        create_nested(entry, slots, custom_types)
      end

    # `group == nil` filters out groups that are members of another group —
    # they are emitted by their parent, not here
    group_items =
      for entry <- slots.groups, entry[:nested] == scope, entry[:group] == nil do
        create_group(entry, slots, custom_types)
      end
      |> Enum.reject(&is_nil/1)

    sorted = Enum.sort_by(field_items ++ nested_items ++ group_items, &elem(&1, 0))

    {Enum.map(sorted, &elem(&1, 1)), scope_anchor(sorted)}
  end

  # A nested declaration becomes a paneldynamic question; its scope's
  # elements become the template. Anchored at its first member field.
  defp create_nested(entry, slots, custom_types) do
    {template, anchor} = create_scope(entry.name, slots, custom_types)
    {anchor, nested_question(entry, template)}
  end

  # A group's members are the fields, nested declarations, and groups
  # referencing it; scope agreement is already validated, so membership needs
  # no scope filter. A member group contributes its own anchor, so a group
  # holding only another group still renders at that group's first field.
  # Memberless groups emit nothing — which cascades: a group whose only member
  # is an empty group is empty too.
  defp create_group(entry, slots, custom_types) do
    field_members =
      for {field, index} <- slots.fields, field[:group] == entry.name do
        {index, to_struct(field, index, custom_types)}
      end

    nested_members =
      for nested <- slots.nesteds, nested[:group] == entry.name do
        create_nested(nested, slots, custom_types)
      end

    group_members =
      for group <- slots.groups, group[:group] == entry.name do
        create_group(group, slots, custom_types)
      end
      |> Enum.reject(&is_nil/1)

    case Enum.sort_by(field_members ++ nested_members ++ group_members, &elem(&1, 0)) do
      [] ->
        nil

      [{anchor, _} | _] = members ->
        {anchor, create_panel(entry, Enum.map(members, &elem(&1, 1)))}
    end
  end

  defp scope_anchor([]), do: nil
  defp scope_anchor([{anchor, _} | _]), do: anchor

  defp create_panel(group_def, members) do
    %Instance.Element{
      name: group_def.name,
      type: "panel",
      title: declared_text(group_def, :title),
      groupType: group_def[:type],
      visibleIf: group_def[:visible_if],
      enableIf: group_def[:enable_if],
      elements: members
    }
  end

  defp nested_question(entry, template) do
    %Instance.Question{
      name: entry.name,
      type: "paneldynamic",
      title: declared_text(entry, :title),
      description: entry[:description],
      templateElements: template,
      templateTitle: declared_text(entry, :entry_title),
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
      requiredLabel: declared_text(entry, :required_label),
      visibleIf: entry[:visible_if],
      enableIf: entry[:enable_if]
    }
  end

  defp to_struct(%{type: type} = entry, index, custom_types) do
    cond do
      type in Validator.question_types() or type in custom_types -> question_struct(entry, type)
      type in Validator.element_types() -> element_struct(entry, type, index)
    end
  end

  defp question_struct(entry, type) do
    %Instance.Question{
      name: entry.name,
      type: type,
      inputType: entry[:input_type],
      title: declared_text(entry, :label),
      placeholder: entry[:placeholder],
      description: entry[:description],
      defaultValue: entry[:default],
      choices: entry[:options],
      choicesFromQuestion: entry[:choices_from],
      choiceValuesFromQuestion: entry[:choice_value],
      choiceTextsFromQuestion: entry[:choice_text],
      choicesFromQuestionMode: entry[:choices_mode],
      noChoicesText: entry[:no_choices_text],
      validators: create_validators(entry),
      isRequired: entry[:required],
      requiredLabel: declared_text(entry, :required_label),
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
          | title: declared_text(entry, :label),
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

  # Display text a slot declares, keeping "set to blank" distinguishable from
  # "not set at all". HEEx omits the key entirely when the attribute is absent,
  # so label={nil} and label={false} arrive as a present-but-blank value and
  # become "" — meaning "render no label". An absent attribute stays nil, which
  # the renderer fills in from the field name.
  defp declared_text(entry, key) do
    case Map.fetch(entry, key) do
      {:ok, value} -> if Instance.blank?(value), do: "", else: value
      :error -> nil
    end
  end

  # Validators - flattened attrs plus the explicit :validators escape hatch

  defp create_validators(entry) do
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
      type: get_validator_type!(map),
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

  defp get_validator_type!(map) do
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
end
