defmodule DynamicForm.Instance do
  @moduledoc """
  Configuration struct that defines the complete form structure using SurveyJS-compatible format.

  An Instance represents a complete form definition with all its elements (questions and panels),
  validators, and backend submission configuration.

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
      ...>   ],
      ...>   backend: %DynamicForm.Instance.Backend{
      ...>     module: MyApp.EmailBackend,
      ...>     function: :submit,
      ...>     config: [recipient: "admin@example.com"]
      ...>   }
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
  (see `DynamicForm.Instance.FromSlots`). Questions and elements defined with a
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
    :backend,
    :metadata,
    inserted_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t() | nil,
          description: String.t() | nil,
          elements: [Question.t() | Element.t()],
          backend: Backend.t() | nil,
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
  """
  def decode!(data) when is_binary(data) do
    data
    |> Jason.decode!()
    |> decode!()
  end

  def decode!(data) when is_map(data) do
    DynamicForm.Instance.Decoder.decode_instance(data)
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

    ## Read-Only Questions

    Questions can be marked as `readOnly: true` to prevent user editing while still
    displaying the value. This is commonly used in edit forms where certain
    fields (like IDs, creation timestamps, or verified emails) should be visible
    but immutable.

    **Important**: Read-only HTML fields are not submitted by browsers. The
    `DynamicForm.RendererLive` component automatically preserves read-only field
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
      :requiredIf,
      :readOnly,
      :enableIf,
      :visibleIf,
      :rateMin,
      :rateMax,
      :rateStep,
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
            requiredIf: String.t() | nil,
            readOnly: boolean() | nil,
            enableIf: String.t() | nil,
            visibleIf: String.t() | nil,
            rateMin: integer() | nil,
            rateMax: integer() | nil,
            rateStep: integer() | nil,
            metadata: map() | nil,
            slot: map() | nil
          }
  end

  defimpl Jason.Encoder, for: Question do
    def encode(question, opts) do
      # Build map with only non-nil values to match SurveyJS format
      map =
        %{
          name: question.name,
          type: question.type
        }
        |> maybe_put(:inputType, question.inputType)
        |> maybe_put(:title, question.title)
        |> maybe_put(:placeholder, question.placeholder)
        |> maybe_put(:description, question.description)
        |> maybe_put(:defaultValue, question.defaultValue)
        |> maybe_put(:choices, encode_choices(question.choices))
        |> maybe_put(:validators, question.validators)
        |> maybe_put(:isRequired, question.isRequired)
        |> maybe_put(:requiredIf, question.requiredIf)
        |> maybe_put(:readOnly, question.readOnly)
        |> maybe_put(:enableIf, question.enableIf)
        |> maybe_put(:visibleIf, question.visibleIf)
        |> maybe_put(:rateMin, question.rateMin)
        |> maybe_put(:rateMax, question.rateMax)
        |> maybe_put(:rateStep, question.rateStep)
        |> maybe_put(:metadata, question.metadata)

      Jason.Encode.map(map, opts)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)

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
    - `"panel"` - Container for grouping questions together
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
    def encode(element, opts) do
      # Build map with only non-nil values to match SurveyJS format
      map =
        %{
          name: element.name,
          type: element.type
        }
        |> maybe_put(:title, element.title)
        |> maybe_put(:html, element.html)
        |> maybe_put(:elements, element.elements)
        |> maybe_put(:visibleIf, element.visibleIf)
        |> maybe_put(:enableIf, element.enableIf)
        |> maybe_put(:imageLink, element.imageLink)
        |> maybe_put(:imageWidth, element.imageWidth)
        |> maybe_put(:imageHeight, element.imageHeight)
        |> maybe_put(:imageFit, element.imageFit)
        |> maybe_put(:metadata, element.metadata)

      Jason.Encode.map(map, opts)
    end

    defp maybe_put(map, _key, nil), do: map
    defp maybe_put(map, key, value), do: Map.put(map, key, value)
  end

  defmodule Backend do
    @moduledoc """
    Configuration for the form submission backend.

    The backend module should implement the `DynamicForm.Backend` behaviour.

    ## Example

        %Backend{
          module: MyApp.EmailBackend,
          function: :submit,
          config: [recipient: "admin@example.com"],
          name: "Email Backend",
          description: "Sends form submissions via email"
        }
    """

    @enforce_keys [:module, :function, :config]
    defstruct [
      :module,
      :function,
      :config,
      :name,
      :description
    ]

    @type t :: %__MODULE__{
            module: module(),
            function: atom(),
            config: Keyword.t(),
            name: String.t() | nil,
            description: String.t() | nil
          }
  end

  defimpl Jason.Encoder, for: Backend do
    def encode(backend, opts) do
      Jason.Encode.map(
        %{
          module: to_string(backend.module),
          function: backend.function,
          config: encode_config(backend.config),
          name: backend.name,
          description: backend.description
        },
        opts
      )
    end

    # Convert keyword list to a list of maps for JSON serialization
    defp encode_config(config) when is_list(config) do
      Enum.map(config, fn {key, value} ->
        %{"key" => to_string(key), "value" => value}
      end)
    end

    defp encode_config(config), do: config
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
  Returns a copy of the instance with all `:slot` fields removed.

  Slot-defined elements (see `DynamicForm.Instance.FromSlots`) carry their raw
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
        %{question | slot: nil}

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
          backend: instance.backend,
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
