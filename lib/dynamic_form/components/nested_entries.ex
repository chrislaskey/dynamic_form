defmodule DynamicForm.Components.NestedEntries do
  @moduledoc """
  Rendering for `paneldynamic` questions: the repeating nested-form section —
  its header and add button, one namespaced child form per entry with its
  remove button, and the section-level errors.

  Internal module — not part of the public API.
  """

  use Phoenix.Component

  alias DynamicForm.Components
  alias DynamicForm.Helpers
  alias DynamicForm.Instance
  alias DynamicForm.Instance.Elements
  alias DynamicForm.NestedForms
  alias DynamicForm.Renderer.Component
  alias DynamicForm.Visibility

  @doc """
  Renders the nested-form section for a `paneldynamic` question. `disabled`
  is the question's effective disabled state, computed by the caller.
  """
  def nested_form(question, form, opts, disabled) do
    components = Keyword.get(opts, :components)

    children =
      NestedForms.list_entry_changesets(question, form.source.params || %{},
        custom_field_types: Keyword.get(opts, :custom_field_types)
      )

    count = length(children)

    assigns = %{
      question: question,
      form: form,
      children: children,
      disabled: disabled,
      label: Instance.label_text(question),
      required: !!question.isRequired,
      required_label: Instance.required_label_text(question),
      errors: entry_list_errors(form[String.to_atom(question.name)], components),
      components: components,
      opts: if(disabled, do: Keyword.put(opts, :disabled, true), else: opts),
      path: Enum.join(Keyword.get(opts, :entry_path, []) ++ [question.name], "."),
      target: Keyword.get(opts, :target),
      confirm_text: entry_confirm_text(question),
      # The configured label still does its job on hover and for screen
      # readers, now that the control itself is an icon
      remove_label: question.removePanelText || "Remove",
      show_add?: show_add_entry?(question, count, disabled),
      show_remove?: show_remove_entry?(question, count, disabled)
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
                render_entry_contents(%{
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

  # The contents of one nested-form entry, in two columns: the entry title and
  # child fields on the left, the remove button on the right. The button
  # top-aligns with the first field, and its column collapses entirely when the
  # entry can't be removed. `min-w-0` lets the fields column shrink rather than
  # overflow the entry. The nested_entry container is style-only; the
  # add/remove behavior stays here.
  defp render_entry_contents(assigns) do
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
      |> Helpers.Form.get_params()
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

    elements = Visibility.visible_elements(question.templateElements || [], context)

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
      <%= Component.render_element(element, @form, @opts) %>
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
  defp entry_list_errors(field, components) do
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

  defp entry_title(question, index) do
    if Instance.blank?(question.templateTitle) do
      nil
    else
      String.replace(question.templateTitle, "{panelIndex}", to_string(index + 1))
    end
  end
end
