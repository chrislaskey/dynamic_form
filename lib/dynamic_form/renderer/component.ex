defmodule DynamicForm.Renderer.Component do
  @moduledoc """
  A pure functional form component

  This component renders the form HTML based on a DynamicForm.Instance configuration.

  ## Example

      <DynamicForm.Renderer.Component.render
        instance={@form_instance}
        form={@form}
        submit_text="Submit Form"
        phx_submit="submit"
        phx_change="validate"
        form_id="my-dynamic-form"
      />

  """

  use Phoenix.Component

  alias DynamicForm.CarryForward
  alias DynamicForm.ComponentResolver
  alias DynamicForm.FieldTypes
  alias DynamicForm.Helpers
  alias DynamicForm.Instance
  alias DynamicForm.Instance.Elements
  alias DynamicForm.Renderer.Components.ContentElements
  alias DynamicForm.Renderer.Components.NestedEntries
  alias DynamicForm.Visibility

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
        "functions it exports override the built-ins per function — see DynamicForm.ComponentResolver"
  )

  attr(:custom_field_types, :map,
    default: nil,
    doc:
      "Custom field types map (type name => Ecto type), merged over the " <>
        ":dynamic_form, :custom_field_types config — see DynamicForm.FieldTypes"
  )

  def render(assigns) do
    instance = DynamicForm.Parser.FromData.parse!(assigns.instance)
    submit_text = assigns.submit_text || "Submit"
    uploads = Map.get(assigns, :uploads, %{})
    parent_id = Map.get(assigns, :parent_id)
    components = ComponentResolver.resolve(Map.get(assigns, :components))
    field_types = FieldTypes.resolve(Map.get(assigns, :custom_field_types))

    assigns =
      assigns
      |> assign(:instance, instance)
      |> assign(:submit_text, submit_text)
      |> assign(:uploads, uploads)
      |> assign(:parent_id, parent_id)
      |> assign(:components, components)
      |> assign(:field_types, field_types)
      |> assign(:form_data, Helpers.Form.get_applied_data(assigns.form))
      |> assign(:questions, Elements.questions_by_name(instance.elements))
      |> assign(
        :visible_elements,
        Visibility.visible_elements(instance.elements, Helpers.Form.get_params(assigns.form))
      )

    ~H"""
    <.form
      :let={f}
      for={@form}
      id={@form_id}
      phx-submit={@phx_submit}
      phx-change={@phx_change}
      phx-target={@target}
    >
      <%= for element <- @visible_elements do %>
        <%= render_element(element, f, disabled: @disabled, gettext: @gettext, uploads: @uploads, parent_id: @parent_id, components: @components, custom_field_types: @field_types, target: @target, form_data: @form_data, questions: @questions) %>
      <% end %>

      <div :if={!@hide_submit} class="mt-6 flex items-center justify-end gap-x-6">
        <%= if ComponentResolver.provides?(@components, :button) do %>
          {ComponentResolver.render(@components, :button, %{
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

  # Dispatch to the appropriate renderer based on element type. Public so
  # Renderer.Components.NestedEntries and ContentElements can recurse back
  # into it for their members — internal, not part of the public API.
  @doc false
  def render_element(%Instance.Question{} = question, form, opts) do
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
          {ComponentResolver.render(@components, :label, %{
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

  def render_element(%Instance.Element{} = element, form, opts) do
    ContentElements.render(element, form, opts)
  end

  # A choice question whose choices are all carried forward has none to show
  # until its source has entries. Rather than an empty control, render the
  # question's noChoicesText — "Add an age group above to assign it here".
  defp no_choices?(%Instance.Question{noChoicesText: nil}, _opts), do: false

  defp no_choices?(%Instance.Question{} = question, opts) do
    question.choicesFromQuestion != nil and CarryForward.resolve_choices(question, opts) == []
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
      field: Helpers.Form.put_data(field, Keyword.get(opts, :form_data)),
      entry: entry,
      label: question_label(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      errors: Enum.map(errors, &ComponentResolver.translate_error(components, &1)),
      components: components
    }

    ~H"""
    <div class="mb-4">
      <%= if @label do %>
        {ComponentResolver.render(@components, :label, %{
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
        {ComponentResolver.render(@components, :error, %{
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
      {ComponentResolver.render(@components, :input, %{
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
      {ComponentResolver.render(@components, :input, %{
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
      {ComponentResolver.render(@components, :input, %{
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
      {ComponentResolver.render(@components, :input_radio_group, %{
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
      {ComponentResolver.render(@components, :input, %{
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
      {ComponentResolver.render(@components, :input_checkbox_group, %{
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
      {ComponentResolver.render(@components, :input, %{
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
      {ComponentResolver.render(@components, :input_radio_group, %{
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
  # built by DynamicForm.NestedForms.list_entry_changesets/3 — the same function the
  # validation path uses, so rendered errors always match validation.
  #
  # The add/remove buttons emit "add_nested_entry"/"remove_nested_entry" events carrying a
  # dot-separated `path` (e.g. "addresses" or "contacts.0.phones" when
  # nested). DynamicForm.Renderer.LiveComponent handles these automatically; standalone
  # Renderer.Component users must handle them in their own LiveView.
  defp render_question(%Instance.Question{type: "paneldynamic"} = question, form, opts) do
    NestedEntries.nested_form(question, form, opts, question_disabled?(question, form, opts))
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
      choices: CarryForward.resolve_choices(question, opts),
      label: question_label(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      components: Keyword.get(opts, :components)
    }

    ~H"""
    <div class="mb-4">
      {ComponentResolver.render(@components, :input, %{
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
      not Visibility.condition_met?(question.enableIf, Helpers.Form.get_params(form))
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
      values: list_readonly_values(field.value),
      disabled: question_unavailable?(question, form, opts)
    }

    ~H"""
    <input :for={value <- @values} :if={!@disabled} type="hidden" name={@name} value={value} />
    """
  end

  defp readonly_value_inputs(_question, _form, _opts), do: nil

  defp list_readonly_values(nil), do: []
  defp list_readonly_values(values) when is_list(values), do: Enum.map(values, &to_string/1)
  defp list_readonly_values(value), do: [to_string(value)]
end
