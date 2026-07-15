defmodule DynamicForm.Changeset do
  @moduledoc """
  Helper functions for creating dynamic changesets from DynamicForm.Instance configurations.

  This module converts a form instance into an Ecto changeset, allowing for validation
  and form handling using Phoenix's standard patterns.
  """

  alias DynamicForm.Instance

  @doc """
  Creates a changeset from a DynamicForm.Instance configuration.

  Only form questions are included in the changeset. Elements (panels, HTML, etc.)
  are filtered out as they don't collect user input.

  ## Parameters

    * `instance` - The DynamicForm.Instance struct
    * `params` - The form parameters to validate (defaults to empty map)

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
  def create_changeset(%Instance{} = instance, params \\ %{}) do
    questions = get_questions(instance.elements)
    types = build_types_map(questions)
    required_fields = get_required_fields(questions, params)

    # Decode JSON-encoded file upload fields
    decoded_params =
      params
      |> decode_upload_params(questions)
      |> normalize_array_params(questions)

    {%{}, types}
    |> Ecto.Changeset.cast(decoded_params, Map.keys(types), empty_values: [])
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
  def build_types_map(questions) when is_list(questions) do
    Enum.reduce(questions, %{}, fn question, acc ->
      # Convert question name to atom for Ecto
      field_atom = String.to_atom(question.name)
      Map.put(acc, field_atom, map_question_type(question))
    end)
  end

  # Maps SurveyJS question types to Ecto types
  defp map_question_type(%Instance.Question{type: "text", inputType: "number"}), do: :decimal
  defp map_question_type(%Instance.Question{type: "text"}), do: :string
  defp map_question_type(%Instance.Question{type: "comment"}), do: :string
  defp map_question_type(%Instance.Question{type: "dropdown"}), do: :string
  defp map_question_type(%Instance.Question{type: "radiogroup"}), do: :string
  defp map_question_type(%Instance.Question{type: "boolean"}), do: :boolean
  defp map_question_type(%Instance.Question{type: "file"}), do: {:array, :map}
  defp map_question_type(%Instance.Question{type: "checkbox"}), do: {:array, :string}
  defp map_question_type(%Instance.Question{type: "tagbox"}), do: {:array, :string}
  defp map_question_type(%Instance.Question{type: "rating"}), do: :integer
  defp map_question_type(%Instance.Question{type: type}) when is_binary(type), do: :string

  defp decode_upload_params(params, questions) do
    upload_fields =
      questions
      |> Enum.filter(&(&1.type == "file"))
      |> Enum.map(& &1.name)

    Enum.reduce(upload_fields, params, fn field_name, acc ->
      case Map.get(acc, field_name) do
        value when is_binary(value) ->
          # Decode JSON string to list of maps
          case Jason.decode(value) do
            {:ok, decoded} -> Map.put(acc, field_name, decoded)
            {:error, _} -> acc
          end

        # Already decoded or nil
        _ ->
          acc
      end
    end)
  end

  # Checkbox groups submit a hidden empty entry under `name[]` so that clearing
  # every box still submits the field. Strip those empty strings from
  # array-valued params before casting; an all-empty selection becomes nil so
  # validate_required still applies to empty checkbox groups.
  defp normalize_array_params(params, questions) do
    array_fields =
      questions
      |> Enum.filter(&(&1.type in ["checkbox", "tagbox"]))
      |> Enum.map(& &1.name)

    Enum.reduce(array_fields, params, fn field_name, acc ->
      case Map.get(acc, field_name) do
        values when is_list(values) ->
          case Enum.reject(values, &(&1 == "")) do
            [] -> Map.put(acc, field_name, nil)
            selected -> Map.put(acc, field_name, selected)
          end

        _ ->
          acc
      end
    end)
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
