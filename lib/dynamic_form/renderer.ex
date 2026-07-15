defmodule DynamicForm.Renderer do
  @moduledoc """
  A pure functional component that renders dynamic forms using SurveyJS-compatible format.

  This component renders the form HTML based on a DynamicForm.Instance configuration.
  Use this for advanced cases where you want custom state management.

  ## Example

      <DynamicForm.Renderer.render
        instance={@form_instance}
        form={@form}
        submit_text="Submit Form"
        phx_submit="submit"
        phx_change="validate"
        form_id="my-dynamic-form"
      />

  ## External Submit Button

  You can place a submit button outside the form element by:

  1. Setting `hide_submit` to `true`
  2. Using `DynamicForm.submit_button/1` anywhere on the page with the form's ID

  ### Example

      # Form without submit button
      <DynamicForm.Renderer.render
        instance={@form_instance}
        form={@form}
        form_id="my-form"
        hide_submit={true}
        phx_submit="submit"
      />

      # Submit button elsewhere on the page
      <div class="sticky bottom-0">
        <DynamicForm.submit_button form="my-form">
          Save Changes
        </DynamicForm.submit_button>
      </div>
  """

  use Phoenix.Component

  alias DynamicForm.CoreComponents
  alias DynamicForm.Instance

  attr(:instance, :any,
    required: true,
    doc:
      "The form instance configuration. Can be an Instance struct, JSON string, or map that will be decoded into an Instance."
  )

  attr(:form, Phoenix.HTML.Form, required: true, doc: "The Phoenix form struct")
  attr(:submit_text, :string, default: nil, doc: "Text for the submit button")
  attr(:phx_submit, :string, default: "submit", doc: "Phoenix event name for form submission")

  attr(:phx_change, :string,
    default: "validate",
    doc: "Phoenix event name for form validation"
  )

  attr(:target, :any, default: nil, doc: "Phoenix LiveView target for events")
  attr(:form_id, :string, default: "dynamic-form", doc: "HTML ID for the form element")
  attr(:disabled, :boolean, default: false, doc: "Whether the form is disabled")

  attr(:hide_submit, :boolean,
    default: false,
    doc: "Whether to hide the submit button (useful when using an external submit button)"
  )

  attr(:gettext, :atom,
    default: DynamicForm.Gettext,
    doc: "Gettext backend module for translations"
  )

  attr(:uploads, :map,
    default: %{},
    doc: "Upload configurations for file fields"
  )

  attr(:parent_id, :string,
    default: nil,
    doc: "Parent component ID for LiveComponent communication"
  )

  def render(assigns) do
    # Decode instance if needed
    instance = decode_instance(assigns.instance)
    submit_text = assigns.submit_text || "Submit"
    uploads = Map.get(assigns, :uploads, %{})
    parent_id = Map.get(assigns, :parent_id)

    assigns =
      assigns
      |> assign(:instance, instance)
      |> assign(:submit_text, submit_text)
      |> assign(:uploads, uploads)
      |> assign(:parent_id, parent_id)

    ~H"""
    <.form
      :let={f}
      for={@form}
      id={@form_id}
      phx-submit={@phx_submit}
      phx-change={@phx_change}
      phx-target={@target}
    >
      <%= for element <- visible_elements(@instance.elements, @form) do %>
        <%= render_element(element, f, disabled: @disabled, gettext: @gettext, uploads: @uploads, parent_id: @parent_id) %>
      <% end %>

      <div :if={!@hide_submit} class="mt-6 flex items-center justify-end gap-x-6">
        <button
          type="submit"
          disabled={@disabled}
          class="rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <%= if @disabled do %>
            Saving...
          <% else %>
            <%= @submit_text %>
          <% end %>
        </button>
      </div>
    </.form>
    """
  end

  # Filter elements (questions and panels) based on visibility conditions
  defp visible_elements(elements, form) do
    Enum.filter(elements, fn element ->
      should_display_element?(element, form)
    end)
  end

  defp should_display_element?(%Instance.Question{} = question, form) do
    DynamicForm.Visibility.question_visible?(question, get_form_params(form))
  end

  defp should_display_element?(%Instance.Element{} = element, form) do
    DynamicForm.Visibility.element_visible?(element, get_form_params(form))
  end

  # Get current params from form
  defp get_form_params(form) do
    form.source.changes
  rescue
    _ -> %{}
  end

  # Dispatch to appropriate renderer based on element type
  defp render_element(%Instance.Question{} = question, form, opts) do
    render_question(question, form, opts)
  end

  defp render_element(%Instance.Element{} = element, form, opts) do
    render_panel_or_html(element, form, opts)
  end

  # Render HTML elements
  defp render_panel_or_html(%Instance.Element{type: "html"} = element, _form, _opts) do
    html_content = element.html || ""

    assigns = %{html: html_content}

    ~H"""
    <div class="mb-4">
      <%= Phoenix.HTML.raw(@html) %>
    </div>
    """
  end

  # Render image elements
  defp render_panel_or_html(%Instance.Element{type: "image"} = element, _form, _opts) do
    assigns = %{element: element}

    ~H"""
    <div class="mb-4">
      <img
        src={@element.imageLink}
        alt={@element.title || @element.name}
        style={image_style(@element)}
        class="rounded-md max-w-full"
      />
    </div>
    """
  end

  # Render panel elements (containers)
  defp render_panel_or_html(%Instance.Element{type: "panel"} = element, form, opts) do
    title = element.title
    elements = element.elements || []

    # A disabled panel (enableIf false) disables every question inside it
    opts =
      if DynamicForm.Visibility.condition_met?(element.enableIf, get_form_params(form)) do
        opts
      else
        Keyword.put(opts, :disabled, true)
      end

    # Filter visible elements within the panel
    visible_panel_elements = visible_elements(elements, form)

    assigns = %{
      element: element,
      title: title,
      elements: visible_panel_elements,
      form: form,
      opts: opts
    }

    ~H"""
    <CoreComponents.section title={@title}>
      <%= for item <- @elements do %>
        <%= case item do %>
          <% %Instance.Question{} = question -> %>
            <%= render_question(question, @form, @opts) %>
          <% %Instance.Element{} = nested_element -> %>
            <%= render_panel_or_html(nested_element, @form, @opts) %>
        <% end %>
      <% end %>
    </CoreComponents.section>
    """
  end

  # Fallback for unknown element types
  defp render_panel_or_html(element, _form, _opts) do
    assigns = %{element: element}

    ~H"""
    <div class="mb-4 rounded-md bg-yellow-50 p-4">
      <div class="flex">
        <div class="ml-3">
          <h3 class="text-sm font-medium text-yellow-800">Unknown element type</h3>
          <div class="mt-2 text-sm text-yellow-700">
            <p>Element "<%= @element.name %>" has unsupported type: <%= @element.type %></p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Render a text input question
  defp render_question(%Instance.Question{type: "text"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)

    # Determine input type
    input_type = question.inputType || "text"

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      label: label,
      input_type: input_type
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input
        field={@form[@field_atom]}
        type={@input_type}
        label={@label}
        placeholder={@question.placeholder}
        disabled={@disabled}
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a comment/textarea question
  defp render_question(%Instance.Question{type: "comment"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      label: label
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input
        field={@form[@field_atom]}
        type="textarea"
        label={@label}
        placeholder={@question.placeholder}
        disabled={@disabled}
        rows="4"
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a dropdown/select question
  defp render_question(%Instance.Question{type: "dropdown"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)
    choices = normalize_choices(question.choices)

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input
        field={@form[@field_atom]}
        type="select"
        label={@label}
        options={@choices}
        prompt="Select an option..."
        disabled={@disabled}
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a radiogroup question
  defp render_question(%Instance.Question{type: "radiogroup"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)
    choices = normalize_choices(question.choices)

    # Get style from metadata
    style =
      case get_in(question.metadata || %{}, ["style"]) do
        "horizontal" -> :horizontal
        "vertical" -> :vertical
        :horizontal -> :horizontal
        :vertical -> :vertical
        _ -> :vertical
      end

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label,
      style: style
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input_radio_group
        field={@form[@field_atom]}
        label={@label}
        options={@choices}
        style={@style}
        disabled={@disabled}
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a boolean/checkbox question
  defp render_question(%Instance.Question{type: "boolean"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)

    # For checkboxes, the label is displayed inline, so include description if present
    label =
      if question.description do
        Phoenix.HTML.raw(
          "#{question.title || String.capitalize(question.name)}<br><span class=\"text-gray-500\">#{question.description}</span>"
        )
      else
        question.title || String.capitalize(question.name)
      end

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      label: label
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input
        field={@form[@field_atom]}
        type="checkbox"
        label={@label}
        disabled={@disabled}
      />
    </div>
    """
  end

  # Render a file upload question
  defp render_question(%Instance.Question{type: "file"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    uploads = Keyword.get(opts, :uploads, %{})
    parent_id = Keyword.get(opts, :parent_id)

    assigns = %{
      question: question,
      form: form,
      disabled: disabled,
      uploads: uploads,
      parent_id: parent_id
    }

    ~H"""
    <.live_component
      module={DynamicForm.DirectUpload}
      id={"#{@question.name}-upload-component"}
      field={@question}
      form={@form}
      disabled={@disabled}
      uploads={@uploads}
      parent_id={@parent_id}
    />
    """
  end

  # Render a checkbox question (multi-select checkbox group)
  defp render_question(%Instance.Question{type: "checkbox"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)
    choices = normalize_choices(question.choices)
    label = question_label(question)

    style =
      case get_in(question.metadata || %{}, ["style"]) do
        "horizontal" -> :horizontal
        :horizontal -> :horizontal
        _ -> :vertical
      end

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label,
      style: style
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input_checkbox_group
        field={@form[@field_atom]}
        label={@label}
        options={@choices}
        style={@style}
        disabled={@disabled}
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a tagbox question (multi-select dropdown)
  defp render_question(%Instance.Question{type: "tagbox"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)
    choices = normalize_choices(question.choices)
    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input
        field={@form[@field_atom]}
        type="select"
        label={@label}
        options={@choices}
        multiple={true}
        disabled={@disabled}
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a rating question as a horizontal group of numeric radio buttons
  defp render_question(%Instance.Question{type: "rating"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)
    label = question_label(question)

    rate_min = question.rateMin || 1
    rate_max = question.rateMax || 5
    rate_step = question.rateStep || 1

    choices =
      rate_min
      |> Stream.iterate(&(&1 + rate_step))
      |> Enum.take_while(&(&1 <= rate_max))
      |> Enum.map(&{to_string(&1), &1})

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label
    }

    ~H"""
    <div class="mb-4">
      <CoreComponents.input_radio_group
        field={@form[@field_atom]}
        label={@label}
        options={@choices}
        style={:horizontal}
        disabled={@disabled}
      />
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Fallback for unknown question types
  defp render_question(question, _form, _opts) do
    assigns = %{question: question}

    ~H"""
    <div class="mb-4 rounded-md bg-red-50 p-4">
      <div class="flex">
        <div class="ml-3">
          <h3 class="text-sm font-medium text-red-800">Unknown question type</h3>
          <div class="mt-2 text-sm text-red-700">
            <p>Question "<%= @question.name %>" has unsupported type: <%= @question.type %></p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper to decode instance from various formats
  defp decode_instance(%Instance{} = instance), do: instance

  defp decode_instance(data) when is_binary(data) or is_map(data) do
    Instance.decode!(data)
  end

  # Build label with required indicator
  defp question_label(question) do
    if question.isRequired do
      Phoenix.HTML.raw(
        "#{question.title || String.capitalize(question.name)} <span class=\"text-red-500\">*</span>"
      )
    else
      question.title || String.capitalize(question.name)
    end
  end

  # A question is disabled when the form is disabled, it is read-only, or its
  # enableIf expression evaluates to false
  defp question_disabled?(question, form, opts) do
    Keyword.get(opts, :disabled, false) || question.readOnly ||
      not DynamicForm.Visibility.condition_met?(question.enableIf, get_form_params(form))
  end

  # Normalize decoded choices to {label, value} tuples for form components
  defp normalize_choices(nil), do: []

  defp normalize_choices(choices) when is_list(choices) do
    Enum.map(choices, fn
      {text, value} -> {text, value}
      value when is_binary(value) -> {value, value}
      value -> {to_string(value), value}
    end)
  end

  defp image_style(element) do
    [
      element.imageWidth && "width: #{element.imageWidth};",
      element.imageHeight && "height: #{element.imageHeight};",
      element.imageFit && "object-fit: #{element.imageFit};"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end
end
