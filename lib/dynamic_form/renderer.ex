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
        <%= render_element(element, f, disabled: @disabled, gettext: @gettext, uploads: @uploads, parent_id: @parent_id, components: @components, custom_field_types: @field_types, target: @target) %>
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

  # Dispatch to appropriate renderer based on element type
  defp render_element(%Instance.Question{} = question, form, opts) do
    render_question(question, form, opts)
  end

  defp render_element(%Instance.Element{} = element, form, opts) do
    render_panel_or_html(element, form, opts)
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
  defp render_panel_or_html(%Instance.Element{type: "custom", slot: entry}, form, _opts)
       when not is_nil(entry) do
    assigns = %{entry: entry, form: form}

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
      opts: opts,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    {Components.render(@components, :section, %{
      title: @title,
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

  # The contents of a panel, wrapped in a slot for the section component
  defp render_panel_elements(elements, form, opts) do
    assigns = %{elements: elements, form: form, opts: opts}

    ~H"""
    <%= for item <- @elements do %>
      <%= case item do %>
        <% %Instance.Question{} = question -> %>
          <%= render_question(question, @form, @opts) %>
        <% %Instance.Element{} = nested_element -> %>
          <%= render_panel_or_html(nested_element, @form, @opts) %>
      <% end %>
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
      field: field,
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
        disabled: @disabled
      })}
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
    choices = normalize_choices(question.choices)

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
    choices = normalize_choices(question.choices)
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
  # The add/remove buttons emit "add_entry"/"remove_entry" events carrying a
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
      show_add?: show_add_entry?(question, count, disabled),
      show_remove?: show_remove_entry?(question, count, disabled)
    }

    ~H"""
    <div class="mb-4">
      {Components.render(@components, :label, %{
        for: "#{@form.id}_#{@question.name}",
        inner_block: [
          %{__slot__: :inner_block, inner_block: fn _changed, _arg -> @label end}
        ]
      })}
      <%= if @question.description do %>
        <p class="mt-2 text-sm text-gray-500"><%= @question.description %></p>
      <% end %>
      <%!-- Keeps the field present in params when every panel is removed --%>
      <input type="hidden" name={"#{@form.name}[#{@question.name}][__empty__]"} value="" />
      <p :if={@children == []} class="mt-2 text-sm italic text-gray-500">
        {@question.noEntriesText || "No entries yet."}
      </p>
      <div
        :for={{child, index} <- Enum.with_index(@children)}
        class="mt-3 rounded-lg border border-gray-200 p-4"
      >
        <div class="mb-2 flex items-center justify-between">
          <h4 class="text-sm font-semibold text-gray-900">{entry_title(@question, index)}</h4>
          <button
            :if={@show_remove?}
            type="button"
            phx-click="remove_entry"
            phx-value-path={@path}
            phx-value-index={index}
            phx-target={@target}
            data-confirm={@confirm_text}
            class="btn btn-sm btn-ghost text-red-600"
          >
            {@question.removePanelText || "Remove"}
          </button>
        </div>
        {render_entry(@question, @form, child, index, @opts)}
      </div>
      <%= for msg <- @errors do %>
        {Components.render(@components, :error, %{
          inner_block: [%{__slot__: :inner_block, inner_block: fn _changed, _arg -> msg end}]
        })}
      <% end %>
      <div :if={@show_add?} class="mt-3">
        <button
          type="button"
          phx-click="add_entry"
          phx-value-path={@path}
          phx-target={@target}
          class="btn btn-sm"
        >
          {@question.addPanelText || "Add new"}
        </button>
      </div>
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

  defp render_custom_question(question, form, opts) do
    disabled = question_disabled?(question, form, opts)
    field_atom = String.to_atom(question.name)

    assigns = %{
      question: question,
      form: form,
      field_atom: field_atom,
      disabled: disabled,
      choices: normalize_choices(question.choices),
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

    elements = visible_template_elements(question.templateElements || [], context)

    assigns = %{elements: elements, form: child_form, opts: child_opts}

    ~H"""
    <%= for element <- @elements do %>
      <%= render_element(element, @form, @opts) %>
    <% end %>
    """
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

  defp show_add_entry?(question, count, disabled) do
    question.allowAddPanel != false && !disabled &&
      (is_nil(question.maxPanelCount) || count < question.maxPanelCount)
  end

  defp show_remove_entry?(question, count, disabled) do
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
