defmodule DynamicForm.Instance.Decoder do
  @moduledoc """
  Decodes SurveyJS-compatible JSON data or maps into DynamicForm.Instance structs.

  This module handles the conversion of SurveyJS-format JSON form configurations
  into proper Elixir structs, including nested elements and special types.

  ## SurveyJS Format

  This decoder accepts SurveyJS-compatible JSON format. See:
  https://surveyjs.io/form-library/documentation

  ## Examples

      iex> json = ~s({"id": "my-form", "title": "My Form", "elements": []})
      iex> map = Jason.decode!(json)
      iex> DynamicForm.Instance.Decoder.decode_instance(map)
      %DynamicForm.Instance{id: "my-form", title: "My Form", elements: []}
  """

  alias DynamicForm.Instance

  # SurveyJS question types that we recognize
  @question_types ~w(text comment dropdown radiogroup boolean file checkbox rating tagbox paneldynamic)

  # SurveyJS element/panel types
  @element_types ~w(html panel image)

  @doc """
  Decodes a map into a DynamicForm.Instance struct.

  Supports SurveyJS format with `pages` array or flat `elements` array.
  """
  def decode_instance(data) when is_map(data) do
    # Handle SurveyJS pages format - flatten all pages into a single elements list
    elements =
      case Map.get(data, "pages") do
        pages when is_list(pages) and pages != [] -> flatten_pages(pages)
        _ -> Map.get(data, "elements", [])
      end

    %Instance{
      id: Map.get(data, "id") || generate_id(),
      title: Map.get(data, "title"),
      description: Map.get(data, "description"),
      elements: decode_elements(elements),
      metadata: Map.get(data, "metadata"),
      inserted_at: decode_datetime(Map.get(data, "inserted_at")),
      updated_at: decode_datetime(Map.get(data, "updated_at"))
    }
  end

  @doc """
  Decodes a list of elements (questions and panels).
  """
  def decode_elements(elements) when is_list(elements) do
    Enum.map(elements, &decode_element/1)
  end

  def decode_elements(nil), do: nil

  @doc """
  Decodes a single element based on its type.

  SurveyJS uses `type` to distinguish between question types and element types.
  """
  def decode_element(%{"type" => type} = data) when type in @question_types do
    decode_question(data)
  end

  def decode_element(%{"type" => type} = data) when type in @element_types do
    decode_panel_or_html(data)
  end

  # Fallback: if it has choices or isRequired, treat as question
  def decode_element(%{"choices" => _} = data), do: decode_question(data)
  def decode_element(%{"isRequired" => _} = data), do: decode_question(data)

  # Otherwise treat as element
  def decode_element(data), do: decode_panel_or_html(data)

  @doc """
  Decodes a question map into an Instance.Question struct.
  """
  def decode_question(data) when is_map(data) do
    %Instance.Question{
      name: Map.fetch!(data, "name"),
      type: Map.fetch!(data, "type"),
      inputType: Map.get(data, "inputType"),
      title: Map.get(data, "title"),
      placeholder: Map.get(data, "placeholder"),
      description: Map.get(data, "description"),
      defaultValue: Map.get(data, "defaultValue"),
      choices: decode_choices(Map.get(data, "choices")),
      validators: decode_validators(Map.get(data, "validators")),
      isRequired: Map.get(data, "isRequired"),
      # `requiredMark` is SurveyJS's name for the same property
      requiredLabel: Map.get(data, "requiredLabel") || Map.get(data, "requiredMark"),
      requiredIf: Map.get(data, "requiredIf"),
      readOnly: Map.get(data, "readOnly"),
      enableIf: Map.get(data, "enableIf"),
      visibleIf: Map.get(data, "visibleIf"),
      rateMin: Map.get(data, "rateMin"),
      rateMax: Map.get(data, "rateMax"),
      rateStep: Map.get(data, "rateStep"),
      templateElements: decode_template_elements(data),
      templateTitle: Map.get(data, "templateTitle"),
      panelCount: Map.get(data, "panelCount"),
      minPanelCount: Map.get(data, "minPanelCount"),
      maxPanelCount: Map.get(data, "maxPanelCount"),
      allowAddPanel: Map.get(data, "allowAddPanel"),
      allowRemovePanel: Map.get(data, "allowRemovePanel"),
      addPanelText: Map.get(data, "addPanelText") || Map.get(data, "panelAddText"),
      removePanelText: Map.get(data, "removePanelText") || Map.get(data, "panelRemoveText"),
      noEntriesText: Map.get(data, "noEntriesText"),
      confirmDelete: Map.get(data, "confirmDelete"),
      confirmDeleteText: Map.get(data, "confirmDeleteText"),
      keyName: Map.get(data, "keyName"),
      keyDuplicationError: Map.get(data, "keyDuplicationError"),
      defaultPanelValue: Map.get(data, "defaultPanelValue"),
      generateIds: Map.get(data, "generateIds"),
      choicesFromQuestion: Map.get(data, "choicesFromQuestion"),
      choiceValuesFromQuestion: Map.get(data, "choiceValuesFromQuestion"),
      choiceTextsFromQuestion: Map.get(data, "choiceTextsFromQuestion"),
      choicesFromQuestionMode: Map.get(data, "choicesFromQuestionMode"),
      noChoicesText: Map.get(data, "noChoicesText"),
      metadata: Map.get(data, "metadata")
    }
  end

  # `templateElements` holds a paneldynamic question's repeating template;
  # `questions` is SurveyJS's legacy alias for the same property.
  defp decode_template_elements(data) do
    decode_elements(Map.get(data, "templateElements") || Map.get(data, "questions"))
  end

  @doc """
  Decodes a panel or HTML element map into an Instance.Element struct.
  """
  def decode_panel_or_html(data) when is_map(data) do
    %Instance.Element{
      name: Map.fetch!(data, "name"),
      type: Map.get(data, "type", "html"),
      title: Map.get(data, "title"),
      groupType: Map.get(data, "groupType"),
      html: Map.get(data, "html"),
      elements: decode_elements(Map.get(data, "elements")),
      visibleIf: Map.get(data, "visibleIf"),
      enableIf: Map.get(data, "enableIf"),
      imageLink: Map.get(data, "imageLink"),
      imageWidth: Map.get(data, "imageWidth"),
      imageHeight: Map.get(data, "imageHeight"),
      imageFit: Map.get(data, "imageFit"),
      metadata: Map.get(data, "metadata")
    }
  end

  @doc """
  Decodes a validator list.
  """
  def decode_validators(nil), do: nil
  def decode_validators([]), do: []

  def decode_validators(validators) when is_list(validators) do
    Enum.map(validators, &decode_validator/1)
  end

  @doc """
  Decodes a single validator map into an Instance.Validator struct.
  """
  def decode_validator(data) when is_map(data) do
    %Instance.Validator{
      type: Map.fetch!(data, "type"),
      minLength: Map.get(data, "minLength"),
      maxLength: Map.get(data, "maxLength"),
      minValue: Map.get(data, "minValue"),
      maxValue: Map.get(data, "maxValue"),
      regex: Map.get(data, "regex"),
      text: Map.get(data, "text")
    }
  end

  @doc """
  Decodes question choices.

  SurveyJS supports:
  - Simple strings: ["option1", "option2"]
  - Objects: [{"value": "v1", "text": "Label 1"}, ...]
  """
  def decode_choices(nil), do: nil
  def decode_choices([]), do: []

  def decode_choices(choices) when is_list(choices) do
    Enum.map(choices, fn
      # SurveyJS object format
      %{"value" => value, "text" => text} ->
        {text, value}

      # Simple string (value equals text)
      value when is_binary(value) ->
        value

      # Integer choice
      value when is_integer(value) ->
        value

      # Already a tuple
      {text, value} ->
        {text, value}

      # Legacy array format [label, value]
      [label, value] when is_binary(label) ->
        {label, value}

      # Fallback
      other ->
        other
    end)
  end

  @doc """
  Decodes a DateTime from an ISO8601 string.
  """
  def decode_datetime(nil), do: nil

  def decode_datetime(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end

  def decode_datetime(%DateTime{} = dt), do: dt

  # Private helpers

  # Flatten a SurveyJS `pages` array into a single elements list. Each page's
  # title (when present) is preserved as an html heading element so multi-page
  # forms render as one continuous form without losing structure.
  defp flatten_pages(pages) do
    Enum.flat_map(pages, fn page ->
      elements = Map.get(page, "elements", [])

      case Map.get(page, "title") do
        title when is_binary(title) and title != "" ->
          heading = %{
            "type" => "html",
            "name" => "#{Map.get(page, "name", "page")}-title",
            "html" =>
              "<h2>#{Phoenix.HTML.html_escape(title) |> Phoenix.HTML.safe_to_string()}</h2>"
          }

          [heading | elements]

        _ ->
          elements
      end
    end)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
