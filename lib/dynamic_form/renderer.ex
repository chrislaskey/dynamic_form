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

  alias DynamicForm.{Components, FieldTypes, Instance, NestedForms}

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
    # Decode instance if needed
    instance = decode_instance(assigns.instance)
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
      |> assign(:questions, questions_by_name(instance.elements))

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
      label: question_label(question)
    }

    ~H"""
    <%= if @no_choices? do %>
      <div class="mb-4">
        {Components.render(@components, :label, %{
          inner_block: [
            %{__slot__: :inner_block, inner_block: fn _changed, _arg -> @label end}
          ]
        })}
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
    question.choicesFromQuestion != nil and resolve_choices(question, opts) == []
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
      title: element.title,
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
      errors: Enum.map(errors, &Components.translate_error(components, &1)),
      components: components
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :label, %{
        for: @field.id,
        inner_block: [
          %{__slot__: :inner_block, inner_block: fn _changed, _arg -> @label end}
        ]
      })}
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
      input_type: input_type,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: @input_type,
        label: @label,
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
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "textarea",
        label: @label,
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
    choices = resolve_choices(question, opts)

    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "select",
        label: @label,
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
    choices = resolve_choices(question, opts)

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
      style: style,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input_radio_group, %{
        field: @form[@field_atom],
        label: @label,
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
      label: label,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "checkbox",
        label: @label,
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
    choices = resolve_choices(question, opts)
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
      style: style,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input_checkbox_group, %{
        field: @form[@field_atom],
        label: @label,
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
    choices = resolve_choices(question, opts)
    label = question_label(question)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: choices,
      label: label,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: "select",
        label: @label,
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
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input_radio_group, %{
        field: @form[@field_atom],
        label: @label,
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
          <h3 class="text-xl font-bold">{@label}</h3>
          <div :if={@question.description} class="text-gray-500">
            {@question.description}
          </div>
        </div>
        <button
          :if={@show_add?}
          type="button"
          phx-click="add_nested_entry"
          phx-value-path={@path}
          phx-target={@target}
          class="btn btn-sm shrink-0"
        >
          {@question.addPanelText || "Add new"}
        </button>
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
      choices: resolve_choices(question, opts),
      label: question_label(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :input, %{
        field: @form[@field_atom],
        type: @question.type,
        label: @label,
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

    context =
      parent_form
      |> get_form_params()
      |> stringify_keys()
      |> Map.merge(stringify_keys(child.changes))

    child_opts =
      opts
      |> Keyword.put(
        :entry_path,
        Keyword.get(opts, :entry_path, []) ++ [question.name, to_string(index)]
      )
      # This entry's own values and questions, so a carried-forward source
      # name resolves innermost-first — see resolve_choices/2.
      |> Keyword.put(:entry_data, Ecto.Changeset.apply_changes(child))
      |> Keyword.put(:entry_questions, questions_by_name(question.templateElements || []))

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
    case question.templateTitle do
      nil -> nil
      title -> String.replace(title, "{panelIndex}", to_string(index + 1))
    end
  end

  defp stringify_keys(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> stringify_keys()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
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

  # A question's choices: its own `choices`, or — when it declares
  # `choicesFromQuestion` — one choice per entry of the source question
  # (SurveyJS's carry forward).
  #
  # The source name resolves innermost-first, matching how `{field}`
  # expressions scope inside a template: the enclosing entry's values first,
  # then form-level. That is what lets a field inside one entry list "this
  # entry's own children" as well as a top-level nested form's entries.
  defp resolve_choices(%Instance.Question{choicesFromQuestion: nil} = question, _opts) do
    normalize_choices(question.choices)
  end

  defp resolve_choices(%Instance.Question{} = question, opts) do
    case source_question(question.choicesFromQuestion, opts) do
      %Instance.Question{type: "paneldynamic"} -> carried_from_entries(question, opts)
      %Instance.Question{} = source -> carried_from_choices(source, question, opts)
      nil -> carried_from_entries(question, opts)
    end
  end

  # The source question, innermost-first: a question in the enclosing entry's
  # template shadows a form-level one of the same name.
  defp source_question(name, opts) do
    entry_scope = Keyword.get(opts, :entry_questions) || %{}
    form_scope = Keyword.get(opts, :questions) || %{}

    Map.get(entry_scope, name) || Map.get(form_scope, name)
  end

  # One choice per entry of a nested form.
  defp carried_from_entries(question, opts) do
    case source_value(question.choicesFromQuestion, opts) do
      nil ->
        []

      value ->
        value
        |> NestedForms.entries()
        |> Enum.with_index()
        |> Enum.flat_map(&carried_choice(&1, question))
    end
  end

  # The source's own choices, optionally narrowed to what the user has (or
  # hasn't) selected there — SurveyJS's choicesFromQuestionMode.
  defp carried_from_choices(source, question, opts) do
    choices = normalize_choices(source.choices)

    case question.choicesFromQuestionMode do
      mode when mode in [nil, "all"] ->
        choices

      mode when mode in ["selected", "unselected"] ->
        selected =
          source.name
          |> source_value(opts)
          |> List.wrap()
          |> Enum.map(&to_string/1)

        Enum.filter(choices, fn {_text, value} ->
          to_string(value) in selected == (mode == "selected")
        end)

      other ->
        raise ArgumentError,
              "#{question.name} has choices_mode #{inspect(other)} — " <>
                ~s|expected "all", "selected", or "unselected"|
    end
  end

  defp source_value(name, opts) do
    entry_scope = Keyword.get(opts, :entry_data) || %{}
    form_scope = Keyword.get(opts, :form_data) || %{}

    field_value(entry_scope, name) || field_value(form_scope, name)
  end

  # Questions by name for one scope, for resolving a carried-forward source.
  # Panels are transparent — their questions belong to the enclosing scope —
  # while a nested form's template is its own scope.
  defp questions_by_name(elements) when is_list(elements) do
    Enum.reduce(elements, %{}, fn
      %Instance.Question{} = question, acc ->
        Map.put(acc, question.name, question)

      %Instance.Element{elements: nested}, acc when is_list(nested) ->
        Map.merge(acc, questions_by_name(nested))

      _element, acc ->
        acc
    end)
  end

  defp questions_by_name(_elements), do: %{}

  # Values reach here as applied changeset data (atom keys) in the managed
  # lifecycle, and as raw params (string keys) when render-only mode renders
  # against a form the parent built from params. Read both rather than
  # silently finding nothing.
  defp field_value(map, name) when is_map(map) and is_binary(name) do
    case Map.fetch(map, String.to_atom(name)) do
      {:ok, value} -> value
      :error -> Map.get(map, name)
    end
  end

  defp field_value(_map, _name), do: nil

  # One choice per source entry: the value identifies it (the entry id
  # unless choiceValuesFromQuestion names a field), the text labels it.
  # Entries missing either are skipped rather than rendered blank — a
  # half-filled entry isn't a choice yet.
  defp carried_choice({entry, index}, question) when is_map(entry) do
    value = carried_value(entry, question)
    text = carried_text(entry, index, question)

    if blank?(value) or blank?(text), do: [], else: [{to_string(text), to_string(value)}]
  end

  defp carried_choice(_entry, _question), do: []

  defp carried_value(entry, %Instance.Question{choiceValuesFromQuestion: nil}) do
    field_value(entry, NestedForms.id_field())
  end

  defp carried_value(entry, %Instance.Question{choiceValuesFromQuestion: field}) do
    field_value(entry, field)
  end

  defp carried_text(entry, index, %Instance.Question{choiceTextsFromQuestion: template})
       when is_binary(template) do
    if String.contains?(template, "{") do
      interpolate_choice_text(template, entry, index)
    else
      field_value(entry, template)
    end
  end

  defp carried_text(_entry, _index, _question), do: nil

  # "{min} - {max}" against the entry's values, plus {panelIndex} for the
  # 1-based position — the same token templateTitle uses.
  #
  # A template referencing a field the entry hasn't filled in yields nil, not
  # a half-formed label: "6 - " is not a choice worth offering.
  defp interpolate_choice_text(template, entry, index) do
    template = String.replace(template, "{panelIndex}", to_string(index + 1))

    fields =
      ~r/\{([^}]+)\}/
      |> Regex.scan(template, capture: :all_but_first)
      |> List.flatten()

    values = Enum.map(fields, &to_string(field_value(entry, &1)))

    if Enum.any?(values, &blank?/1) do
      nil
    else
      fields
      |> Enum.zip(values)
      |> Enum.reduce(template, fn {field, value}, acc ->
        String.replace(acc, "{#{field}}", value)
      end)
      |> String.trim()
    end
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_value), do: false

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
