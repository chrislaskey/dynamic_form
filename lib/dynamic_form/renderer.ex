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

  alias DynamicForm.{CarryForward, Components, FieldTypes, Helpers, Instance, NestedForms}
  alias DynamicForm.Instance.Elements

  # A group with no groupType of its own lays its members out in a row
  @default_group_type "horizontal"

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

  attr(:components, :atom,
    default: nil,
    doc:
      "Custom components module (e.g. the app's Phoenix-generated CoreComponents); " <>
        "functions it exports override the built-ins per function — see DynamicForm.Components"
  )

  attr(:custom_field_types, :map,
    default: nil,
    doc:
      "Custom field types map (type name => Ecto type), merged over the " <>
        ":dynamic_form, :custom_field_types config — see DynamicForm.FieldTypes"
  )

  def render(assigns) do
    instance = Instance.decode!(assigns.instance)
    submit_text = assigns.submit_text || "Submit"
    uploads = Map.get(assigns, :uploads, %{})
    parent_id = Map.get(assigns, :parent_id)
    components = Components.resolve(Map.get(assigns, :components))
    field_types = FieldTypes.resolve(Map.get(assigns, :custom_field_types))

    assigns =
      assigns
      |> assign(:instance, instance)
      |> assign(:submit_text, submit_text)
      |> assign(:uploads, uploads)
      |> assign(:parent_id, parent_id)
      |> assign(:components, components)
      |> assign(:field_types, field_types)
      |> assign(:form_data, applied_form_data(assigns.form))
      |> assign(:questions, Elements.questions_by_name(instance.elements))

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
        <%= render_element(element, f, disabled: @disabled, gettext: @gettext, uploads: @uploads, parent_id: @parent_id, components: @components, custom_field_types: @field_types, target: @target, form_data: @form_data, questions: @questions) %>
      <% end %>

      <div :if={!@hide_submit} class="mt-6 flex items-center justify-end gap-x-6">
        <%= if Components.provides?(@components, :button) do %>
          {Components.render(@components, :button, %{
            type: "submit",
            disabled: @disabled,
            rest: %{},
            inner_block: submit_label_slot(@disabled, @submit_text)
          })}
        <% else %>
          <button
            type="submit"
            disabled={@disabled}
            class="phx-submit-loading:opacity-75 btn btn-primary"
          >
            <%= if @disabled do %>
              Saving...
            <% else %>
              <%= @submit_text %>
            <% end %>
          </button>
        <% end %>
      </div>
    </.form>
    """
  end

  # Minimal inner_block slot carrying the submit button label, for delegating
  # the submit button to a components module's button/1
  defp submit_label_slot(disabled, submit_text) do
    text = if disabled, do: "Saving...", else: submit_text
    [%{__slot__: :inner_block, inner_block: fn _changed, _arg -> text end}]
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

  # The whole form's current values, applied once per render and handed to
  # slot bodies via DynamicForm.form_data/1. Render-only mode renders against
  # a parent-owned form, so a non-changeset source falls back to its params.
  defp applied_form_data(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}) do
    Ecto.Changeset.apply_changes(changeset)
  end

  defp applied_form_data(%Phoenix.HTML.Form{params: params}), do: params

  # Attach the form-level data to the value a slot body receives. It rides in
  # the form's options, which is private plumbing — DynamicForm.form_data/1 is
  # the contract. Only slot bodies are decorated: the root form is rendered by
  # Phoenix.Component.form/1, which spreads its options onto the <form> tag.
  defp put_form_data(%Phoenix.HTML.FormField{} = field, data) do
    %{field | form: put_form_data(field.form, data)}
  end

  defp put_form_data(%Phoenix.HTML.Form{} = form, data) do
    %{form | options: Keyword.put(form.options, :form_data, data)}
  end

  # Dispatch to appropriate renderer based on element type
  defp render_element(%Instance.Question{} = question, form, opts) do
    assigns = %{
      question: question,
      form: form,
      opts: opts,
      no_choices?: no_choices?(question, opts),
      components: Keyword.get(opts, :components),
      label: question_label(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question)
    }

    ~H"""
    <%= if @no_choices? do %>
      <div class="mb-4">
        <%= if @label do %>
          {Components.render(@components, :label, %{
            required: @required,
            required_label: @required_label,
            inner_block: [
              %{__slot__: :inner_block, inner_block: fn _changed, _arg -> @label end}
            ]
          })}
        <% end %>
        <p class="mt-2 text-sm text-gray-500">{@question.noChoicesText}</p>
      </div>
    <% else %>
      {render_question(@question, @form, @opts)}{readonly_value_inputs(@question, @form, @opts)}
    <% end %>
    """
  end

  defp render_element(%Instance.Element{} = element, form, opts) do
    render_panel_or_html(element, form, opts)
  end

  # A choice question whose choices are all carried forward has none to show
  # until its source has entries. Rather than an empty control, render the
  # question's noChoicesText — "Add an age group above to assign it here".
  defp no_choices?(%Instance.Question{noChoicesText: nil}, _opts), do: false

  defp no_choices?(%Instance.Question{} = question, opts) do
    question.choicesFromQuestion != nil and CarryForward.resolve_choices(question, opts) == []
  end

  # Render HTML elements defined with a slot body (see Instance.FromSlots).
  # The body is compile-checked HEEx, so unlike the html-string clause below it
  # is escaped by default and can read the defining template's assigns.
  defp render_panel_or_html(%Instance.Element{type: "html", slot: entry}, _form, _opts)
       when not is_nil(entry) do
    assigns = %{entry: entry}

    ~H"""
    <div class="mb-4">
      {render_slot(@entry)}
    </div>
    """
  end

  # Render fully custom elements: the slot body receives the Phoenix form so
  # it can read current values, e.g. <:field type="custom" :let={form}>
  defp render_panel_or_html(%Instance.Element{type: "custom", slot: entry}, form, opts)
       when not is_nil(entry) do
    assigns = %{entry: entry, form: put_form_data(form, Keyword.get(opts, :form_data))}

    ~H"""
    <div class="mb-4">
      {render_slot(@entry, @form)}
    </div>
    """
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
      # nil rather than "" for a blank title: the group component renders no
      # heading when it has none
      title: if(Instance.blank?(element.title), do: nil, else: element.title),
      group_type: element.groupType || @default_group_type,
      # The effective state: a group inherits it from a disabled form or an
      # enclosing disabled group as well as from its own enableIf
      disabled: Keyword.get(opts, :disabled, false),
      elements: visible_panel_elements,
      form: form,
      opts: opts,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    {Components.render(@components, :dynamic_form_group, %{
      type: @group_type,
      name: @element.name,
      title: @title,
      disabled: @disabled,
      inner_block: [
        %{
          __slot__: :inner_block,
          inner_block: fn _changed, _arg -> render_panel_elements(@elements, @form, @opts) end
        }
      ]
    })}
    """
  end

  # Unknown element types render nothing — obvious in testing, not
  # broken-looking in production
  defp render_panel_or_html(_element, _form, _opts) do
    assigns = %{}

    ~H""
  end

  # The contents of a panel, wrapped in a slot for the group component
  defp render_panel_elements(elements, form, opts) do
    assigns = %{elements: elements, form: form, opts: opts}

    ~H"""
    <%= for element <- @elements do %>
      <%= render_element(element, @form, @opts) %>
    <% end %>
    """
  end

  # Render a question defined with a slot body: the body receives the
  # Phoenix.HTML.FormField and takes over the control, while the library keeps
  # the label, description, error display, and changeset validation. E.g.
  #
  #   <:field type="text" name="amount" label="Amount" :let={field}>
  #     <input type="range" name={field.name} id={field.id} value={field.value} />
  #   </:field>
  defp render_question(%Instance.Question{slot: entry} = question, form, opts)
       when not is_nil(entry) do
    field = form[String.to_atom(question.name)]
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []
    components = Keyword.get(opts, :components)

    assigns = %{
      question: question,
      field: put_form_data(field, Keyword.get(opts, :form_data)),
      entry: entry,
      label: question_label(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      errors: Enum.map(errors, &Components.translate_error(components, &1)),
      components: components
    }

    ~H"""
    <div class="mb-4">
      <%= if @label do %>
        {Components.render(@components, :label, %{
          for: @field.id,
          required: @required,
          required_label: @required_label,
          inner_block: [
            %{__slot__: :inner_block, inner_block: fn _changed, _arg -> @label end}
          ]
        })}
      <% end %>
      {render_slot(@entry, @field)}
      <%= for msg <- @errors do %>
        {Components.render(@components, :error, %{
          inner_block: [%{__slot__: :inner_block, inner_block: fn _changed, _arg -> msg end}]
        })}
      <% end %>
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a text input question
  defp render_question(%Instance.Question{type: "text"} = question, form, opts) do
    disabled = question_unavailable?(question, form, opts)
    field_atom = String.to_atom(question.name)

    # Determine input type
    input_type = question.inputType || "text"

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      readonly: !disabled && !!question.readOnly,
      label: label,
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      input_type: input_type,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: @input_type,
        label: @label,
        required: @required,
        required_label: @required_label,
        placeholder: @question.placeholder,
        disabled: @disabled,
        readonly: @readonly
      })}
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a comment/textarea question
  defp render_question(%Instance.Question{type: "comment"} = question, form, opts) do
    disabled = question_unavailable?(question, form, opts)
    field_atom = String.to_atom(question.name)

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      readonly: !disabled && !!question.readOnly,
      label: label,
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "textarea",
        label: @label,
        required: @required,
        required_label: @required_label,
        placeholder: @question.placeholder,
        disabled: @disabled,
        readonly: @readonly,
        rows: "4"
      })}
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
    choices = CarryForward.resolve_choices(question, opts)

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label,
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "select",
        label: @label,
        required: @required,
        required_label: @required_label,
        options: @choices,
        prompt: "Select an option...",
        disabled: @disabled
      })}
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
    choices = CarryForward.resolve_choices(question, opts)

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
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      style: style,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input_radio_group, %{
        field: @form[@field_atom],
        label: @label,
        required: @required,
        required_label: @required_label,
        options: @choices,
        style: @style,
        disabled: @disabled
      })}
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
    label = boolean_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      label: label,
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "checkbox",
        label: @label,
        required: @required,
        required_label: @required_label,
        disabled: @disabled
      })}
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
    choices = CarryForward.resolve_choices(question, opts)
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
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      style: style,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input_checkbox_group, %{
        field: @form[@field_atom],
        label: @label,
        required: @required,
        required_label: @required_label,
        options: @choices,
        style: @style,
        disabled: @disabled
      })}
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
    choices = CarryForward.resolve_choices(question, opts)
    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label,
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "select",
        label: @label,
        required: @required,
        required_label: @required_label,
        options: @choices,
        multiple: true,
        disabled: @disabled
      })}
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
      label: label,
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input_radio_group, %{
        field: @form[@field_atom],
        label: @label,
        required: @required,
        required_label: @required_label,
        options: @choices,
        style: :horizontal,
        disabled: @disabled
      })}
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render a paneldynamic question: a repeating group of templateElements the
  # user can add and remove. Each entry renders as its own namespaced
  # sub-form (name: form[question][index][field]) backed by a child changeset
  # built by DynamicForm.NestedForms.entry_changesets/3 — the same function the
  # validation path uses, so rendered errors always match validation.
  #
  # The add/remove buttons emit "add_nested_entry"/"remove_nested_entry" events carrying a
  # dot-separated `path` (e.g. "addresses" or "contacts.0.phones" when
  # nested). DynamicForm.RendererLive handles these automatically; standalone
  # Renderer users must handle them in their own LiveView.
  defp render_question(%Instance.Question{type: "paneldynamic"} = question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    components = Keyword.get(opts, :components)

    children =
      NestedForms.entry_changesets(question, form.source.params || %{},
        custom_field_types: Keyword.get(opts, :custom_field_types)
      )

    count = length(children)

    assigns = %{
      question: question,
      form: form,
      children: children,
      disabled: disabled,
      label: question_label(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      errors: nested_form_errors(form[String.to_atom(question.name)], components),
      components: components,
      opts: if(disabled, do: Keyword.put(opts, :disabled, true), else: opts),
      path: Enum.join(Keyword.get(opts, :entry_path, []) ++ [question.name], "."),
      target: Keyword.get(opts, :target),
      confirm_text: entry_confirm_text(question),
      # The configured label still does its job on hover and for screen
      # readers, now that the control itself is an icon
      remove_label: question.removePanelText || "Remove",
      show_add?: show_add_nested_entry?(question, count, disabled),
      show_remove?: show_remove_nested_entry?(question, count, disabled)
    }

    ~H"""
    <div class="mb-4">
      <%!-- Section header: the title and description on the left, the add
           button on the right. A long title wraps rather than squashing the
           button. --%>
      <div class="mt-6 flex items-start justify-between gap-3">
        <div class="min-w-0">
          <h3 :if={@label} class="text-xl font-bold">
            {@label}<span
              :if={@required && @required_label}
              class="ml-0.5 text-red-500"
            >{@required_label}</span>
          </h3>
          <div :if={@question.description} class="text-gray-500">
            {@question.description}
          </div>
        </div>
        <div :if={@show_add?} class="shrink-0">
          {Components.render(@components, :button, %{
            type: "button",
            # The button only renders when the form is editable — show_add?
            # already accounts for the disabled state
            disabled: false,
            rest: %{
              "phx-click" => "add_nested_entry",
              "phx-value-path" => @path,
              "phx-target" => @target
            },
            inner_block: [
              %{
                __slot__: :inner_block,
                inner_block: fn _changed, _arg -> @question.addPanelText || "Add new" end
              }
            ]
          })}
        </div>
      </div>
      <%!-- Keeps the field present in params when every panel is removed --%>
      <input type="hidden" name={"#{@form.name}[#{@question.name}][__empty__]"} value="" />
      <p :if={@children == []} class="mt-2 text-sm italic text-gray-500">
        {@question.noEntriesText || "No entries yet."}
      </p>
      <%= for {child, index} <- Enum.with_index(@children) do %>
        {Components.render(@components, :nested_entry, %{
          index: index,
          name: @question.name,
          inner_block: [
            %{
              __slot__: :inner_block,
              inner_block: fn _changed, _arg ->
                render_nested_entry_contents(%{
                  question: @question,
                  form: @form,
                  child: child,
                  index: index,
                  opts: @opts,
                  show_remove?: @show_remove?,
                  path: @path,
                  target: @target,
                  confirm_text: @confirm_text,
                  remove_label: @remove_label,
                  title: entry_title(@question, index)
                })
              end
            }
          ]
        })}
      <% end %>
      <%= for msg <- @errors do %>
        {Components.render(@components, :error, %{
          inner_block: [%{__slot__: :inner_block, inner_block: fn _changed, _arg -> msg end}]
        })}
      <% end %>
    </div>
    """
  end

  # Registered custom field types dispatch to the components module's
  # input/1 — apps define a matching clause, e.g.
  # def input(%{type: "multiselect"} = assigns). Unregistered types render
  # nothing: an absent field is obvious in testing without looking broken
  # in production.
  defp render_question(question, form, opts) do
    field_types = Keyword.get(opts, :custom_field_types) || %{}

    if FieldTypes.custom?(field_types, question.type) do
      render_custom_question(question, form, opts)
    else
      assigns = %{}

      ~H""
    end
  end

  # The contents of one nested-form entry, in two columns: the entry title and
  # child fields on the left, the remove button on the right. The button
  # top-aligns with the first field, and its column collapses entirely when the
  # entry can't be removed. `min-w-0` lets the fields column shrink rather than
  # overflow the entry. The nested_entry container is style-only; the
  # add/remove behavior stays here.
  defp render_nested_entry_contents(assigns) do
    ~H"""
    <div class="flex items-start gap-3">
      <div class="min-w-0 flex-1">
        <h4 :if={@title} class="mb-2 text-sm font-semibold text-gray-900">{@title}</h4>
        {render_entry(@question, @form, @child, @index, @opts)}
      </div>
      <button
        :if={@show_remove?}
        type="button"
        phx-click="remove_nested_entry"
        phx-value-path={@path}
        phx-value-index={@index}
        phx-target={@target}
        data-confirm={@confirm_text}
        aria-label={@remove_label}
        title={@remove_label}
        class="btn btn-sm btn-square btn-ghost text-red-600"
      >
        <.trash_icon />
      </button>
    </div>
    """
  end

  # Inlined rather than routed through CoreComponents.icon/1: that renders a
  # `hero-*` class, which only becomes a picture in apps that vendor heroicons.
  # A missing decorative icon is invisible, but a missing icon in an icon-only
  # button leaves a blank square, so this one carries its own path data.
  defp trash_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="1.5"
      stroke="currentColor"
      aria-hidden="true"
      class="size-4"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
      />
    </svg>
    """
  end

  defp render_custom_question(question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: CarryForward.resolve_choices(question, opts),
      label: question_label(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: @question.type,
        label: @label,
        required: @required,
        required_label: @required_label,
        options: @choices,
        placeholder: @question.placeholder,
        disabled: @disabled
      })}
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
    </div>
    """
  end

  # Render one paneldynamic entry: a namespaced child form over the template
  # elements. Visibility inside the template evaluates against panel-local
  # values merged over the form-level values, so both `{panel.field}` and
  # form-level references work.
  defp render_entry(question, parent_form, child, index, opts) do
    child_form =
      to_form(%{child | action: parent_form.source.action},
        as: "#{parent_form.name}[#{question.name}][#{index}]",
        id: "#{parent_form.id}_#{question.name}_#{index}"
      )

    # The entry's position, for a slot body to read as `form.index`. Set
    # directly because to_form/2 maps only :as, :id, :action, and :errors onto
    # struct fields — anything else lands in the form's options. This is the
    # same field Phoenix's own inputs_for/1 fills in for a collection, and it
    # is zero-based like the rest of Phoenix; the `{panelIndex}` placeholder is
    # one-based for SurveyJS compatibility.
    child_form = %{child_form | index: index}

    context =
      parent_form
      |> get_form_params()
      |> Helpers.Map.stringify_keys()
      |> Map.merge(Helpers.Map.stringify_keys(child.changes))

    child_opts =
      opts
      |> Keyword.put(
        :entry_path,
        Keyword.get(opts, :entry_path, []) ++ [question.name, to_string(index)]
      )
      # This entry's own values and questions, so a carried-forward source
      # name resolves innermost-first — see CarryForward.resolve_choices/2.
      |> Keyword.put(:entry_data, Ecto.Changeset.apply_changes(child))
      |> Keyword.put(
        :entry_questions,
        Elements.questions_by_name(question.templateElements || [])
      )

    elements = visible_template_elements(question.templateElements || [], context)

    assigns = %{
      elements: elements,
      form: child_form,
      opts: child_opts,
      entry_id: entry_id(question, child_form)
    }

    ~H"""
    <input
      :if={@entry_id}
      type="hidden"
      name={"#{@form.name}[#{NestedForms.id_field()}]"}
      value={@entry_id}
    />
    <%= for element <- @elements do %>
      <%= render_element(element, @form, @opts) %>
    <% end %>
    """
  end

  # The entry's stable id, carried in a hidden input so it round-trips with
  # the rest of the entry. Seeded once when the form is built or the entry is
  # added — see DynamicForm.NestedForms.seed_entry_ids/2.
  defp entry_id(question, child_form) do
    if NestedForms.generate_ids?(question) do
      child_form[String.to_atom(NestedForms.id_field())].value
    end
  end

  # Suppress the parent-level :paneldynamic marker error — each entry renders
  # its own field errors inline. Count/required errors still show.
  defp nested_form_errors(field, components) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    errors
    |> Enum.reject(fn {_msg, error_opts} -> error_opts[:validation] == :paneldynamic end)
    |> Enum.map(&Components.translate_error(components, &1))
  end

  defp entry_confirm_text(%Instance.Question{confirmDelete: true} = question) do
    question.confirmDeleteText || "Are you sure you want to delete the record?"
  end

  defp entry_confirm_text(_question), do: nil

  defp show_add_nested_entry?(question, count, disabled) do
    question.allowAddPanel != false && !disabled &&
      (is_nil(question.maxPanelCount) || count < question.maxPanelCount)
  end

  defp show_remove_nested_entry?(question, count, disabled) do
    question.allowRemovePanel != false && !disabled && count > (question.minPanelCount || 0)
  end

  defp visible_template_elements(elements, params) do
    Enum.filter(elements, fn
      %Instance.Question{} = question ->
        DynamicForm.Visibility.question_visible?(question, params)

      %Instance.Element{} = element ->
        DynamicForm.Visibility.element_visible?(element, params)
    end)
  end

  defp entry_title(question, index) do
    if Instance.blank?(question.templateTitle) do
      nil
    else
      String.replace(question.templateTitle, "{panelIndex}", to_string(index + 1))
    end
  end

  # A checkbox shows its label inline, with the description under it rather than
  # below the control. A blank title drops both the text and the description,
  # leaving a bare checkbox.
  defp boolean_label(question) do
    case Instance.label_text(question) do
      nil ->
        nil

      text ->
        if Instance.blank?(question.description) do
          text
        else
          {:safe,
           [
             escaped(text),
             ~s(<br><span class="text-gray-500">),
             escaped(question.description),
             ~s(</span>)
           ]}
        end
    end
  end

  # The label text alone. Whoever renders it also renders the required mark,
  # from the `required` and `required_label` assigns — a mark belongs beside a
  # label, so a question with none shows none.
  defp question_label(question), do: Instance.label_text(question)

  # Definition text is escaped before being combined with the library's own
  # markup: a title or description can come from stored JSON, so it is data,
  # not trusted markup. A value deliberately wrapped in `Phoenix.HTML.raw/1`
  # passes through unescaped, which is how a definition opts into markup.
  defp escaped(text) do
    text |> Phoenix.HTML.html_escape() |> elem(1)
  end

  # A question is disabled when the form is disabled, it is read-only, or its
  # enableIf expression evaluates to false
  # Whether the control is rendered `disabled`. Read-only questions are
  # included for the controls HTML has no `readonly` for — see
  # readonly_value_inputs/3 for how their values still submit.
  defp question_disabled?(question, form, opts) do
    question.readOnly || question_unavailable?(question, form, opts)
  end

  # Disabled for a reason other than readOnly: the whole form is submitting,
  # or an enableIf says this question is not part of this submission. Unlike
  # a read-only value, these are meant to be excluded from the params.
  defp question_unavailable?(question, form, opts) do
    Keyword.get(opts, :disabled, false) ||
      not DynamicForm.Visibility.condition_met?(question.enableIf, get_form_params(form))
  end

  # Browsers don't submit disabled inputs, so a read-only question's value
  # would be lost on the next change — permanently inside a nested entry,
  # where merge_data restores top-level keys only. Text and textarea controls
  # render `readonly` and submit themselves; every other control mirrors its
  # value into hidden inputs alongside the disabled control.
  defp readonly_value_inputs(
         %Instance.Question{readOnly: true, type: type} = question,
         form,
         opts
       )
       when type not in ~w(text comment paneldynamic file) do
    field = form[String.to_atom(question.name)]

    assigns = %{
      name: if(type in ~w(checkbox tagbox), do: "#{field.name}[]", else: field.name),
      values: readonly_values(field.value),
      disabled: question_unavailable?(question, form, opts)
    }

    ~H"""
    <input :for={value <- @values} :if={!@disabled} type="hidden" name={@name} value={value} />
    """
  end

  defp readonly_value_inputs(_question, _form, _opts), do: nil

  defp readonly_values(nil), do: []
  defp readonly_values(values) when is_list(values), do: Enum.map(values, &to_string/1)
  defp readonly_values(value), do: [to_string(value)]

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
