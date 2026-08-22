defmodule DynamicForm.Instance do
  @moduledoc """
  Configuration struct that defines the complete form structure using SurveyJS-compatible format.

  An Instance represents a complete form definition with all its elements (questions and panels),
  and validators.

  ## SurveyJS Compatibility

  This library uses SurveyJS-compatible JSON format for form definitions. See:
  https://surveyjs.io/form-library/documentation

  ## Example

      iex> instance = %DynamicForm.Instance{
      ...>   id: "contact-form",
      ...>   title: "Contact Form",
      ...>   description: "Get in touch with us",
      ...>   elements: [
      ...>     %DynamicForm.Instance.Element{
      ...>       name: "intro",
      ...>       type: "html",
      ...>       html: "<h2>Contact Information</h2>"
      ...>     },
      ...>     %DynamicForm.Instance.Question{
      ...>       name: "email",
      ...>       type: "text",
      ...>       inputType: "email",
      ...>       title: "Email Address",
      ...>       isRequired: true
      ...>     }
      ...>   ]
      ...> }

  ## JSON Encoding/Decoding

  Instances can be encoded to JSON and decoded back:

      # Encode to JSON
      json = Jason.encode!(instance)

      # Decode from JSON
      instance = DynamicForm.Instance.decode!(json)

      # Decode from map
      instance = DynamicForm.Instance.decode!(map)

  ## Slot-Defined Instances

  Instances can also be built from `<:field>` slot entries via `DynamicForm.form/1`
  (see `DynamicForm.Parser.Declarative`). Questions and elements defined with a
  slot body carry the raw slot entry in their `:slot` field so the renderer can
  call `Phoenix.Component.render_slot/2` on it. The `:slot` field holds a
  closure, so it is never JSON-encoded; use `strip_slots/1` to compare two
  instances by definition alone.
  """

  @enforce_keys [:id, :elements]
  defstruct [
    :id,
    :title,
    :description,
    :elements,
    :metadata,
    inserted_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          elements: [Question.t() | Element.t()],
          metadata: map(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Decodes a JSON string or map into a DynamicForm.Instance struct.

  ## Examples

      iex> json = ~s({"id": "my-form", "title": "My Form", "elements": []})
      iex> DynamicForm.Instance.decode!(json)
      %DynamicForm.Instance{id: "my-form", title: "My Form", elements: []}

      iex> map = %{"id" => "my-form", "title" => "My Form", "elements" => []}
      iex> DynamicForm.Instance.decode!(map)
      %DynamicForm.Instance{id: "my-form", title: "My Form", elements: []}

  An already-decoded `%DynamicForm.Instance{}` passes through unchanged.
  """
  def decode!(%__MODULE__{} = instance), do: instance

  def decode!(data) when is_binary(data) do
    data
    |> Jason.decode!()
    |> decode!()
  end

  def decode!(data) when is_map(data) do
    DynamicForm.Parser.JSON.decode_instance(data)
  end

  defmodule Question do
    @moduledoc """
    Represents a form question (input field) using SurveyJS-compatible format.

    ## SurveyJS Question Types

    Supported types:
    - `"text"` - Single-line text input (use `inputType` for email, number, etc.)
    - `"comment"` - Multi-line text area
    - `"dropdown"` - Select dropdown
    - `"radiogroup"` - Radio button group
    - `"boolean"` - Checkbox/toggle
    - `"file"` - File upload
    - `"paneldynamic"` - Repeating child form (`templateElements` holds the
      template; the value is a list of maps, one per entry)

    ## Read-Only Questions

    Questions can be marked as `readOnly: true` to prevent user editing while still
    displaying the value. This is commonly used in edit forms where certain
    fields (like IDs, creation timestamps, or verified emails) should be visible
    but immutable.

    **Important**: Read-only HTML fields are not submitted by browsers. The
    `DynamicForm.Renderer.LiveComponent` component automatically preserves read-only field
    values by merging the initial params with form submissions.

    ### Example

        %Question{
          name: "user_id",
          type: "text",
          title: "User ID",
          readOnly: true
        }

    ## Conditional Visibility

    Questions can be conditionally shown based on the value of another question using the
    `visibleIf` expression. When `visibleIf` is `nil`, the question is always visible.

    ### Expression Syntax

    - `"{field} = 'value'"` - Show when field equals value
    - `"{field} notempty"` - Show when field has a value
    - `"{field} empty"` - Show when field is empty

    ### Examples

        # Show when payment_method equals "credit_card"
        %Question{
          name: "credit_card_number",
          type: "text",
          title: "Credit Card Number",
          visibleIf: "{payment_method} = 'credit_card'"
        }

        # Show when email has a value
        %Question{
          name: "email_preferences",
          type: "dropdown",
          title: "Email Preferences",
          visibleIf: "{email} notempty"
        }
    """

    @enforce_keys [:name, :type]
    defstruct [
      :name,
      :type,
      :inputType,
      :title,
      :placeholder,
      :description,
      :defaultValue,
      :choices,
      :validators,
      :isRequired,
      :requiredLabel,
      :requiredIf,
      :readOnly,
      :enableIf,
      :visibleIf,
      :rateMin,
      :rateMax,
      :rateStep,
      :templateElements,
      :templateTitle,
      :panelCount,
      :minPanelCount,
      :maxPanelCount,
      :allowAddPanel,
      :allowRemovePanel,
      :addPanelText,
      :removePanelText,
      :noEntriesText,
      :confirmDelete,
      :confirmDeleteText,
      :keyName,
      :keyDuplicationError,
      :defaultPanelValue,
      :generateIds,
      :choicesFromQuestion,
      :choiceValuesFromQuestion,
      :choiceTextsFromQuestion,
      :choicesFromQuestionMode,
      :noChoicesText,
      :metadata,
      :slot
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            type: String.t(),
            inputType: String.t() | nil,
            title: String.t() | nil,
            placeholder: String.t() | nil,
            description: String.t() | nil,
            defaultValue: any(),
            choices: list() | nil,
            validators: [Validator.t()] | nil,
            isRequired: boolean() | nil,
            requiredLabel: String.t() | nil,
            requiredIf: String.t() | nil,
            readOnly: boolean() | nil,
            enableIf: String.t() | nil,
            visibleIf: String.t() | nil,
            rateMin: integer() | nil,
            rateMax: integer() | nil,
            rateStep: integer() | nil,
            templateElements: [t() | Element.t()] | nil,
            templateTitle: String.t() | nil,
            panelCount: integer() | nil,
            minPanelCount: integer() | nil,
            maxPanelCount: integer() | nil,
            allowAddPanel: boolean() | nil,
            allowRemovePanel: boolean() | nil,
            addPanelText: String.t() | nil,
            removePanelText: String.t() | nil,
            noEntriesText: String.t() | nil,
            confirmDelete: boolean() | nil,
            confirmDeleteText: String.t() | nil,
            keyName: String.t() | nil,
            keyDuplicationError: String.t() | nil,
            defaultPanelValue: map() | nil,
            generateIds: boolean() | nil,
            choicesFromQuestion: String.t() | nil,
            choiceValuesFromQuestion: String.t() | nil,
            choiceTextsFromQuestion: String.t() | nil,
            choicesFromQuestionMode: String.t() | nil,
            noChoicesText: String.t() | nil,
            metadata: map() | nil,
            slot: map() | nil
          }
  end

  defimpl Jason.Encoder, for: Question do
    import DynamicForm.Helpers.Map, only: [put_unless_nil: 3]

    def encode(question, opts) do
      # Build map with only non-nil values to match SurveyJS format
      map =
        %{
          name: question.name,
          type: question.type
        }
        |> put_unless_nil(:inputType, question.inputType)
        |> put_unless_nil(:title, question.title)
        |> put_unless_nil(:placeholder, question.placeholder)
        |> put_unless_nil(:description, question.description)
        |> put_unless_nil(:defaultValue, question.defaultValue)
        |> put_unless_nil(:choices, encode_choices(question.choices))
        |> put_unless_nil(:validators, question.validators)
        |> put_unless_nil(:isRequired, question.isRequired)
        |> put_unless_nil(:requiredLabel, question.requiredLabel)
        |> put_unless_nil(:requiredIf, question.requiredIf)
        |> put_unless_nil(:readOnly, question.readOnly)
        |> put_unless_nil(:enableIf, question.enableIf)
        |> put_unless_nil(:visibleIf, question.visibleIf)
        |> put_unless_nil(:rateMin, question.rateMin)
        |> put_unless_nil(:rateMax, question.rateMax)
        |> put_unless_nil(:rateStep, question.rateStep)
        |> put_unless_nil(:templateElements, question.templateElements)
        |> put_unless_nil(:templateTitle, question.templateTitle)
        |> put_unless_nil(:panelCount, question.panelCount)
        |> put_unless_nil(:minPanelCount, question.minPanelCount)
        |> put_unless_nil(:maxPanelCount, question.maxPanelCount)
        |> put_unless_nil(:allowAddPanel, question.allowAddPanel)
        |> put_unless_nil(:allowRemovePanel, question.allowRemovePanel)
        |> put_unless_nil(:addPanelText, question.addPanelText)
        |> put_unless_nil(:removePanelText, question.removePanelText)
        |> put_unless_nil(:noEntriesText, question.noEntriesText)
        |> put_unless_nil(:confirmDelete, question.confirmDelete)
        |> put_unless_nil(:confirmDeleteText, question.confirmDeleteText)
        |> put_unless_nil(:keyName, question.keyName)
        |> put_unless_nil(:keyDuplicationError, question.keyDuplicationError)
        |> put_unless_nil(:defaultPanelValue, question.defaultPanelValue)
        |> put_unless_nil(:generateIds, question.generateIds)
        |> put_unless_nil(:choicesFromQuestion, question.choicesFromQuestion)
        |> put_unless_nil(:choiceValuesFromQuestion, question.choiceValuesFromQuestion)
        |> put_unless_nil(:choiceTextsFromQuestion, question.choiceTextsFromQuestion)
        |> put_unless_nil(:choicesFromQuestionMode, question.choicesFromQuestionMode)
        |> put_unless_nil(:noChoicesText, question.noChoicesText)
        |> put_unless_nil(:metadata, question.metadata)

      Jason.Encode.map(map, opts)
    end

    # Encode choices in SurveyJS format
    defp encode_choices(nil), do: nil
    defp encode_choices([]), do: []

    defp encode_choices(choices) when is_list(choices) do
      Enum.map(choices, fn
        {text, value} -> %{"value" => value, "text" => text}
        %{value: value, text: text} -> %{"value" => value, "text" => text}
        %{"value" => _, "text" => _} = choice -> choice
        value when is_binary(value) -> value
        other -> other
      end)
    end
  end

  defmodule Element do
    @moduledoc """
    Represents a non-input element in a form using SurveyJS-compatible format.

    Elements are used to add structure and information to forms without collecting user input.
    They support conditional visibility just like questions.

    ## SurveyJS Element Types

    - `"html"` - HTML content (headings, paragraphs, dividers, etc.)
    - `"panel"` - Container for grouping questions together. `groupType` picks
      the layout: `"horizontal"` (default) or `"vertical"`, or a type the
      application's components module defines

    - `"image"` - Display an image (`imageLink`, `imageWidth`, `imageHeight`, `imageFit`)

    ## Examples

        # HTML element with heading
        %Element{
          name: "section-heading",
          type: "html",
          html: "<h2>Personal Information</h2>"
        }

        # HTML element with paragraph
        %Element{
          name: "privacy-notice",
          type: "html",
          html: "<p class='text-gray-600'>We take your privacy seriously.</p>"
        }

        # Panel element with nested questions
        %Element{
          name: "address-panel",
          type: "panel",
          title: "Shipping Address",
          elements: [
            %Question{
              name: "street",
              type: "text",
              title: "Street"
            },
            %Question{
              name: "city",
              type: "text",
              title: "City"
            }
          ]
        }

        # Conditional element (only show when terms accepted)
        %Element{
          name: "thank-you-message",
          type: "html",
          html: "<p>Thank you for accepting our terms!</p>",
          visibleIf: "{accept_terms} = true"
        }
    """

    @enforce_keys [:name, :type]
    defstruct [
      :name,
      :type,
      :title,
      :groupType,
      :html,
      :elements,
      :visibleIf,
      :enableIf,
      :imageLink,
      :imageWidth,
      :imageHeight,
      :imageFit,
      :metadata,
      :slot
    ]

    @type t :: %__MODULE__{
            name: String.t(),
            type: String.t(),
            title: String.t() | nil,
            groupType: String.t() | nil,
            html: String.t() | nil,
            elements: [Question.t() | t()] | nil,
            visibleIf: String.t() | nil,
            enableIf: String.t() | nil,
            imageLink: String.t() | nil,
            imageWidth: String.t() | nil,
            imageHeight: String.t() | nil,
            imageFit: String.t() | nil,
            metadata: map() | nil,
            slot: map() | nil
          }
  end

  defimpl Jason.Encoder, for: Element do
    import DynamicForm.Helpers.Map, only: [put_unless_nil: 3]

    def encode(element, opts) do
      # Build map with only non-nil values to match SurveyJS format
      map =
        %{
          name: element.name,
          type: element.type
        }
        |> put_unless_nil(:title, element.title)
        |> put_unless_nil(:groupType, element.groupType)
        |> put_unless_nil(:html, element.html)
        |> put_unless_nil(:elements, element.elements)
        |> put_unless_nil(:visibleIf, element.visibleIf)
        |> put_unless_nil(:enableIf, element.enableIf)
        |> put_unless_nil(:imageLink, element.imageLink)
        |> put_unless_nil(:imageWidth, element.imageWidth)
        |> put_unless_nil(:imageHeight, element.imageHeight)
        |> put_unless_nil(:imageFit, element.imageFit)
        |> put_unless_nil(:metadata, element.metadata)

      Jason.Encode.map(map, opts)
    end
  end

  defmodule Validator do
    @moduledoc """
    Represents a validation rule for a form question using SurveyJS-compatible format.

    ## SurveyJS Validator Types

    - `"text"` - Text length validation (minLength, maxLength)
    - `"numeric"` - Numeric range validation (minValue, maxValue)
    - `"email"` - Email format validation
    - `"regex"` - Regular expression validation

    ## Examples

        # Text length validator
        %Validator{type: "text", minLength: 2, maxLength: 100}

        # Numeric range validator
        %Validator{type: "numeric", minValue: 1, maxValue: 10}

        # Email format validator
        %Validator{type: "email"}

        # Custom error message
        %Validator{type: "text", minLength: 5, text: "Must be at least 5 characters"}
    """

    @derive Jason.Encoder
    @enforce_keys [:type]
    defstruct [
      :type,
      :minLength,
      :maxLength,
      :minValue,
      :maxValue,
      :regex,
      :text
    ]

    @type t :: %__MODULE__{
            type: String.t(),
            minLength: integer() | nil,
            maxLength: integer() | nil,
            minValue: number() | nil,
            maxValue: number() | nil,
            regex: String.t() | nil,
            text: String.t() | nil
          }
  end

  @doc """
  Whether a definition's display text is blank: `nil`, `false`, or `""`.

  Titles, labels, and headings accept all three to mean "render nothing", so a
  template can compute one without special-casing the absent case:

      <:group name="totals" title={@compact && gettext("Totals")} />
  """
  def blank?(value), do: value in [nil, false, ""]

  @doc """
  The text labelling a question, or `nil` when the definition asks for none.

  A question with no `title` at all falls back to its capitalized name, so
  `<:field type="text" name="email" />` still labels itself "Email". A title
  the definition sets blank (`nil`, `false`, or `""`) means "no label", and
  returns `nil` — callers render no label element, and no required marker,
  since there would be nothing for the marker to sit beside.
  """
  def label_text(%Question{title: nil} = question), do: String.capitalize(question.name)

  def label_text(%Question{title: title}) do
    if blank?(title), do: nil, else: title
  end

  @doc """
  The mark shown beside a required question's label, or `nil` for none.

  A question that sets no `requiredLabel` uses `"*"`. One that sets it blank
  (`nil`, `false`, or `""`) suppresses the mark while staying required, and any
  other value replaces it — `"(required)"`, say.
  """
  def required_label_text(%Question{requiredLabel: nil}), do: "*"

  def required_label_text(%Question{requiredLabel: label}) do
    if blank?(label), do: nil, else: label
  end

  @doc """
  Returns a copy of the instance with all `:slot` fields removed.

  Slot-defined elements (see `DynamicForm.Parser.Declarative`) carry their raw
  slot entry — including its `inner_block` closure — in the `:slot` field.
  Closures capture template assigns, so two otherwise-identical instances can
  compare unequal whenever those assigns change. Stripping the slots yields the
  form *definition* alone, which compares reliably with `==`.
  """
  def strip_slots(%__MODULE__{} = instance) do
    %{instance | elements: strip_element_slots(instance.elements)}
  end

  defp strip_element_slots(nil), do: nil

  defp strip_element_slots(elements) when is_list(elements) do
    Enum.map(elements, fn
      %Question{} = question ->
        %{question | slot: nil, templateElements: strip_element_slots(question.templateElements)}

      %Element{} = element ->
        %{element | slot: nil, elements: strip_element_slots(element.elements)}
    end)
  end

  # Custom encoder for Instance that handles DateTime fields
  defimpl Jason.Encoder, for: __MODULE__ do
    def encode(instance, opts) do
      Jason.Encode.map(
        %{
          id: instance.id,
          title: instance.title,
          description: instance.description,
          elements: instance.elements,
          metadata: instance.metadata,
          inserted_at: encode_datetime(instance.inserted_at),
          updated_at: encode_datetime(instance.updated_at)
        },
        opts
      )
    end

    defp encode_datetime(nil), do: nil
    defp encode_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  end
end
