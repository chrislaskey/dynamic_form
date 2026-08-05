defmodule DynamicForm.Changeset do
  @moduledoc """
  Helper functions for creating dynamic changesets from DynamicForm.Instance configurations.

  This module converts a form instance into an Ecto changeset, allowing for validation
  and form handling using Phoenix's standard patterns.
  """

  alias DynamicForm.{FieldTypes, Instance}

  @doc """
  Creates a changeset from a DynamicForm.Instance configuration.

  Only form questions are included in the changeset. Elements (panels, HTML, etc.)
  are filtered out as they don't collect user input.

  ## Parameters

    * `instance` - The DynamicForm.Instance struct
    * `params` - The form parameters to validate (defaults to empty map)
    * `opts` - Options:
      * `:custom_field_types` - a per-form custom field types map, merged
        over the `:dynamic_form, :custom_field_types` config (see
        `DynamicForm.FieldTypes`)
      * `:visibility_params` - params used to evaluate `visibleIf`/`requiredIf`
        expressions instead of `params`. Used internally when validating
        paneldynamic entries, where expressions can reference both panel-local
        (`{panel.field}`) and form-level values

  ## Returns

  An Ecto.Changeset that can be used with Phoenix forms.

  ## Example

      iex> instance = %DynamicForm.Instance{...}
      iex> changeset = DynamicForm.Changeset.create_changeset(instance, %{"email" => "test@example.com"})
      iex> changeset.valid?
      true

  ## Note

  If you have JSON or a map, decode it to an Instance struct first:

      # Decode at the edge
      instance = DynamicForm.Instance.decode!(json_or_map)
      changeset = DynamicForm.Changeset.create_changeset(instance, params)
  """
  def create_changeset(%Instance{} = instance, params \\ %{}, opts \\ []) do
    field_types = FieldTypes.resolve(Keyword.get(opts, :custom_field_types))
    questions = get_questions(instance.elements)
    types = build_types_map(questions, field_types)
    visibility_params = Keyword.get(opts, :visibility_params) || params
    required_fields = get_required_fields(questions, visibility_params)

    # Decode JSON-encoded file upload fields
    decoded_params =
      params
      |> decode_upload_params(questions)
      |> normalize_array_params(questions, field_types)
      |> normalize_panel_params(questions)

    # Ecto's default empty_values treats the "" a browser submits for every
    # untouched input as empty: required fields error with "can't be blank"
    # and optional non-string fields (number, rating) skip the cast instead
    # of failing it. Array fields are unaffected — normalize_array_params
    # handles their hidden-input empty strings above.
    {%{}, types}
    |> Ecto.Changeset.cast(decoded_params, Map.keys(types))
    |> Ecto.Changeset.validate_required(required_fields)
    |> apply_custom_validations(questions)
    |> validate_dynamic_panels(questions, opts)
  end

  @doc """
  Extracts only Question structs from the elements list, filtering out Elements.

  Recursively extracts questions from panel elements that contain nested elements.

  ## Example

      iex> elements = [
      ...>   %DynamicForm.Instance.Element{name: "intro", type: "html"},
      ...>   %DynamicForm.Instance.Question{name: "email", type: "text"},
      ...>   %DynamicForm.Instance.Element{
      ...>     name: "address-panel",
      ...>     type: "panel",
      ...>     elements: [
      ...>       %DynamicForm.Instance.Question{name: "city", type: "text"}
      ...>     ]
      ...>   }
      ...> ]
      iex> DynamicForm.Changeset.get_questions(elements)
      [
        %DynamicForm.Instance.Question{name: "email", type: "text"},
        %DynamicForm.Instance.Question{name: "city", type: "text"}
      ]
  """
  def get_questions(elements) when is_list(elements) do
    Enum.flat_map(elements, fn element ->
      case element do
        %Instance.Question{} = question ->
          [question]

        %Instance.Element{elements: nested_elements} when is_list(nested_elements) ->
          get_questions(nested_elements)

        %Instance.Element{} ->
          []
      end
    end)
  end

  @doc """
  Builds a map of question names to their Ecto types.

  ## Example

      iex> questions = [
      ...>   %DynamicForm.Instance.Question{name: "email", type: "text"},
      ...>   %DynamicForm.Instance.Question{name: "age", type: "text", inputType: "number"}
      ...> ]
      iex> DynamicForm.Changeset.build_types_map(questions)
      %{email: :string, age: :decimal}
  """
  def build_types_map(questions, field_types \\ %{}) when is_list(questions) do
    Enum.reduce(questions, %{}, fn question, acc ->
      # Convert question name to atom for Ecto
      field_atom = String.to_atom(question.name)
      Map.put(acc, field_atom, map_question_type(question, field_types))
    end)
  end

  # Maps SurveyJS question types to Ecto types. Registered custom field
  # types cast as their declared Ecto type; names can't collide with the
  # built-ins (FieldTypes raises), so registry order doesn't matter.
  defp map_question_type(%Instance.Question{type: type}, field_types)
       when is_map_key(field_types, type),
       do: Map.fetch!(field_types, type)

  defp map_question_type(%Instance.Question{type: "text", inputType: "number"}, _), do: :decimal
  defp map_question_type(%Instance.Question{type: "paneldynamic"}, _), do: {:array, :map}
  defp map_question_type(%Instance.Question{type: "text"}, _), do: :string
  defp map_question_type(%Instance.Question{type: "comment"}, _), do: :string
  defp map_question_type(%Instance.Question{type: "dropdown"}, _), do: :string
  defp map_question_type(%Instance.Question{type: "radiogroup"}, _), do: :string
  defp map_question_type(%Instance.Question{type: "boolean"}, _), do: :boolean
  defp map_question_type(%Instance.Question{type: "file"}, _), do: {:array, :map}
  defp map_question_type(%Instance.Question{type: "checkbox"}, _), do: {:array, :string}
  defp map_question_type(%Instance.Question{type: "tagbox"}, _), do: {:array, :string}
  defp map_question_type(%Instance.Question{type: "rating"}, _), do: :integer
  defp map_question_type(%Instance.Question{type: type}, _) when is_binary(type), do: :string

  defp decode_upload_params(params, questions) do
    upload_fields =
      questions
      |> Enum.filter(&(&1.type == "file"))
      |> Enum.map(& &1.name)

    Enum.reduce(upload_fields, params, &decode_upload_field/2)
  end

  # Decode a JSON-string value to a list of maps; leave already-decoded or
  # nil values untouched
  defp decode_upload_field(field_name, params) do
    with value when is_binary(value) <- Map.get(params, field_name),
         {:ok, decoded} <- Jason.decode(value) do
      Map.put(params, field_name, decoded)
    else
      _ -> params
    end
  end

  # Checkbox groups submit a hidden empty entry under `name[]` so that clearing
  # every box still submits the field. Strip those empty strings from
  # array-valued params before casting; an all-empty selection becomes nil so
  # validate_required still applies to empty checkbox groups. Custom field
  # types declared as {:array, _} get the same treatment.
  defp normalize_array_params(params, questions, field_types) do
    array_fields =
      questions
      |> Enum.filter(
        &(&1.type in ["checkbox", "tagbox"] or FieldTypes.array?(field_types, &1.type))
      )
      |> Enum.map(& &1.name)

    Enum.reduce(array_fields, params, &normalize_array_field/2)
  end

  defp normalize_array_field(field_name, params) do
    case Map.get(params, field_name) do
      values when is_list(values) ->
        Map.put(params, field_name, reject_empty_selections(values))

      _ ->
        params
    end
  end

  # An all-empty selection becomes nil so validate_required still applies
  defp reject_empty_selections(values) do
    case Enum.reject(values, &(&1 == "")) do
      [] -> nil
      selected -> selected
    end
  end

  # Paneldynamic questions are excluded: an empty entry list should fail
  # `isRequired` but Ecto's validate_required treats `[]` as present, so
  # validate_dynamic_panels enforces required-ness for them instead.
  defp get_required_fields(questions, params) do
    questions
    |> Enum.filter(fn question ->
      required =
        question.type != "paneldynamic" &&
          (question.isRequired ||
             DynamicForm.Visibility.condition_met?(question.requiredIf, params, default: false))

      required && DynamicForm.Visibility.question_visible?(question, params)
    end)
    |> Enum.map(&String.to_atom(&1.name))
  end

  defp apply_custom_validations(changeset, questions) do
    Enum.reduce(questions, changeset, fn question, acc ->
      apply_question_validations(acc, question)
    end)
  end

  defp apply_question_validations(changeset, question) do
    validators = question.validators || []
    field_atom = String.to_atom(question.name)

    # Also apply email validation for text inputs with inputType: "email"
    changeset =
      if question.type == "text" && question.inputType == "email" do
        Ecto.Changeset.validate_format(changeset, field_atom, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
      else
        changeset
      end

    # Apply rating range validation from rateMin/rateMax (SurveyJS defaults: 1..5)
    changeset =
      if question.type == "rating" do
        Ecto.Changeset.validate_number(changeset, field_atom,
          greater_than_or_equal_to: question.rateMin || 1,
          less_than_or_equal_to: question.rateMax || 5
        )
      else
        changeset
      end

    Enum.reduce(validators, changeset, fn validator, acc ->
      apply_validator(acc, field_atom, validator)
    end)
  end

  # Apply SurveyJS validator types. A validator's `text` property provides a
  # custom error message.
  defp apply_validator(changeset, field_name, %Instance.Validator{type: "text"} = validator) do
    changeset
    |> maybe_validate_length(field_name, :min, validator.minLength, validator.text)
    |> maybe_validate_length(field_name, :max, validator.maxLength, validator.text)
  end

  defp apply_validator(changeset, field_name, %Instance.Validator{type: "email"} = validator) do
    opts = message_opts(validator.text)
    Ecto.Changeset.validate_format(changeset, field_name, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, opts)
  end

  defp apply_validator(changeset, field_name, %Instance.Validator{type: "numeric"} = validator) do
    changeset
    |> maybe_validate_number(
      field_name,
      :greater_than_or_equal_to,
      validator.minValue,
      validator.text
    )
    |> maybe_validate_number(
      field_name,
      :less_than_or_equal_to,
      validator.maxValue,
      validator.text
    )
  end

  defp apply_validator(
         changeset,
         field_name,
         %Instance.Validator{type: "regex", regex: pattern} = validator
       )
       when not is_nil(pattern) do
    opts = message_opts(validator.text)
    Ecto.Changeset.validate_format(changeset, field_name, Regex.compile!(pattern), opts)
  end

  # Fallback for unknown validator types
  defp apply_validator(changeset, _field_name, _validator) do
    changeset
  end

  defp maybe_validate_length(changeset, _field_name, _key, nil, _message), do: changeset

  defp maybe_validate_length(changeset, field_name, key, value, message) do
    opts = [{key, value} | message_opts(message)]
    Ecto.Changeset.validate_length(changeset, field_name, opts)
  end

  defp maybe_validate_number(changeset, _field_name, _key, nil, _message), do: changeset

  defp maybe_validate_number(changeset, field_name, key, value, message) do
    opts = [{key, value} | message_opts(message)]
    Ecto.Changeset.validate_number(changeset, field_name, opts)
  end

  defp message_opts(nil), do: []
  defp message_opts(message) when is_binary(message), do: [message: message]

  # ---------------------------------------------------------------------------
  # Dynamic panels (paneldynamic)
  # ---------------------------------------------------------------------------

  @doc """
  Builds one child changeset per entry of a paneldynamic question.

  Each entry of the question's value is validated against the question's
  `templateElements` with the same rules as a top-level form (casting,
  required fields, validators, conditional expressions), recursively — so
  nested paneldynamic questions work too. Conditional expressions inside the
  template can reference sibling values as `{panel.field}` (or plain
  `{field}`), and form-level values by their names.

  When the question defines `keyName`, entries duplicating another entry's
  value for that field get an error (message: `keyDuplicationError`).

  Both validation (`create_changeset/3`) and rendering
  (`DynamicForm.Renderer`) call this with the parent's raw params, so the
  changesets — and their errors — are identical in both places.

  `parent_params` is the parent changeset's params map; the entry list is
  read from it under the question's name (either a list or a
  `%{"0" => ...}`-indexed map as submitted by the browser).
  """
  def panel_changesets(
        %Instance.Question{type: "paneldynamic"} = question,
        parent_params,
        opts \\ []
      ) do
    template = %Instance{
      id: "#{question.name}-template",
      elements: question.templateElements || []
    }

    children =
      parent_params
      |> Map.get(question.name)
      |> panel_entries()
      |> Enum.map(fn entry ->
        entry = if is_map(entry), do: entry, else: %{}

        # Panel-local values win over form-level values with the same name;
        # `panel.`-prefixed copies make `{panel.field}` references resolve.
        context =
          parent_params
          |> Map.merge(entry)
          |> Map.merge(panel_prefixed(entry))

        create_changeset(template, entry, Keyword.put(opts, :visibility_params, context))
      end)

    apply_key_duplication(children, question)
  end

  @doc """
  Normalizes a paneldynamic value to a list of entries.

  Browser submissions arrive as an indexed map (`%{"0" => %{...}, "1" =>
  %{...}}`, possibly with non-integer bookkeeping keys such as the always-
  present `__empty__` hidden input); programmatic values are already lists.
  """
  def panel_entries(value) do
    case value do
      list when is_list(list) ->
        list

      %{} = indexed ->
        indexed
        |> Enum.filter(fn {key, _} -> match?({_, ""}, Integer.parse(key)) end)
        |> Enum.sort_by(fn {key, _} -> String.to_integer(key) end)
        |> Enum.map(fn {_, entry} -> entry end)

      _ ->
        []
    end
  end

  @doc """
  The initial params for a newly added panel entry.

  Template questions' `defaultValue`s seed the entry, overridden by the
  question's `defaultPanelValue`.
  """
  def new_panel_entry(%Instance.Question{type: "paneldynamic"} = question) do
    defaults =
      (question.templateElements || [])
      |> get_questions()
      |> Enum.reduce(%{}, fn template_question, acc ->
        case template_question.defaultValue do
          nil -> acc
          default -> Map.put(acc, template_question.name, default)
        end
      end)

    panel_value = Map.new(question.defaultPanelValue || %{}, fn {k, v} -> {to_string(k), v} end)

    Map.merge(defaults, panel_value)
  end

  # Convert indexed-map panel params (as submitted by the browser) into
  # ordered entry lists before casting, so the {:array, :map} cast succeeds
  # and changeset.params holds a stable shape.
  defp normalize_panel_params(params, questions) do
    questions
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(params, fn question, acc ->
      case Map.get(acc, question.name) do
        nil -> acc
        value -> Map.put(acc, question.name, panel_entries(value))
      end
    end)
  end

  defp validate_dynamic_panels(changeset, questions, opts) do
    questions
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(changeset, fn question, acc ->
      validate_panel_question(acc, question, opts)
    end)
  end

  defp validate_panel_question(changeset, question, opts) do
    field = String.to_atom(question.name)
    children = panel_changesets(question, changeset.params, opts)

    changeset
    |> put_applied_panel_entries(question, field, children)
    |> validate_panel_required(question, field, children)
    |> validate_panel_count(question, field)
    |> validate_panel_children(field, children)
  end

  # Replace the raw cast value (string-keyed maps straight from the browser,
  # including `_unused_` bookkeeping keys) with each child changeset's applied
  # data, so apply_changes on the parent yields clean, typed nested maps.
  defp put_applied_panel_entries(changeset, question, field, children) do
    if Map.has_key?(changeset.params, question.name) do
      applied = Enum.map(children, &Ecto.Changeset.apply_changes/1)
      Ecto.Changeset.put_change(changeset, field, applied)
    else
      changeset
    end
  end

  defp validate_panel_required(changeset, %Instance.Question{isRequired: true}, field, []) do
    Ecto.Changeset.add_error(changeset, field, "can't be blank", validation: :required)
  end

  defp validate_panel_required(changeset, _question, _field, _children), do: changeset

  defp validate_panel_count(changeset, question, field) do
    changeset
    |> maybe_validate_panel_length(field, :min, question.minPanelCount)
    |> maybe_validate_panel_length(field, :max, question.maxPanelCount)
  end

  defp maybe_validate_panel_length(changeset, _field, _key, nil), do: changeset
  defp maybe_validate_panel_length(changeset, _field, :min, 0), do: changeset

  defp maybe_validate_panel_length(changeset, field, key, value) do
    Ecto.Changeset.validate_length(changeset, field, [{key, value}])
  end

  # An invalid entry marks the parent invalid. The error carries a
  # `:paneldynamic` marker so the renderer can suppress it — each entry
  # renders its own field errors inline.
  defp validate_panel_children(changeset, field, children) do
    if Enum.all?(children, & &1.valid?) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, field, "is invalid", validation: :paneldynamic)
    end
  end

  defp panel_prefixed(entry) do
    Map.new(entry, fn {key, value} -> {"panel.#{key}", value} end)
  end

  # Enforce keyName uniqueness across entries: any entry repeating an earlier
  # entry's value for the key field gets an error on that field.
  defp apply_key_duplication(children, %Instance.Question{keyName: key_name} = question)
       when is_binary(key_name) and key_name != "" do
    field = String.to_atom(key_name)
    message = question.keyDuplicationError || "value must be unique"

    values = Enum.map(children, &Ecto.Changeset.get_field(&1, field))

    duplicated =
      values
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.frequencies()
      |> Enum.filter(fn {_value, count} -> count > 1 end)
      |> Enum.map(fn {value, _count} -> value end)

    Enum.zip_with(children, values, fn child, value ->
      if value in duplicated do
        Ecto.Changeset.add_error(child, field, message, validation: :key_duplication)
      else
        child
      end
    end)
  end

  defp apply_key_duplication(children, _question), do: children
end
