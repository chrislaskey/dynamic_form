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
    required_fields = get_required_fields(questions, params)

    # Decode JSON-encoded file upload fields
    decoded_params =
      params
      |> decode_upload_params(questions)
      |> normalize_array_params(questions, field_types)

    # Ecto's default empty_values treats the "" a browser submits for every
    # untouched input as empty: required fields error with "can't be blank"
    # and optional non-string fields (number, rating) skip the cast instead
    # of failing it. Array fields are unaffected — normalize_array_params
    # handles their hidden-input empty strings above.
    {%{}, types}
    |> Ecto.Changeset.cast(decoded_params, Map.keys(types))
    |> Ecto.Changeset.validate_required(required_fields)
    |> apply_custom_validations(questions)
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

  defp get_required_fields(questions, params) do
    questions
    |> Enum.filter(fn question ->
      required =
        question.isRequired ||
          DynamicForm.Visibility.condition_met?(question.requiredIf, params, default: false)

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
end
