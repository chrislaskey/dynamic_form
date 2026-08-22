defmodule DynamicForm.Renderer.Components.ValidationSummary do
  @moduledoc """
  A summary of a changeset's validation errors, rendered above the form when
  the `validation_summary` attribute of `DynamicForm.form/1` is set.

  Modes:

    * `"simple"` — a generic message about filling out required fields
    * `"detailed"` — the generic message plus a list of specific field errors

  Internal module — not part of the public API.
  """

  use Phoenix.Component

  alias DynamicForm.Instance.Elements

  attr(:changeset, :any, required: true, doc: "The changeset whose errors are summarized")
  attr(:mode, :string, required: true, doc: ~s|"simple" or "detailed"|)
  attr(:instance, :any, required: true, doc: "The instance, for field labels")

  def validation_summary(assigns) do
    errors = list_changeset_errors(assigns.changeset)
    has_errors = length(errors) > 0

    assigns =
      assigns
      |> assign(:has_errors, has_errors)
      |> assign(:errors, errors)

    ~H"""
    <%= if @has_errors do %>
      <div class="rounded-md bg-red-50 p-4 mb-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="h-5 w-5 text-red-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">
              You must fill out all required fields before marking the section as complete.
            </h3>
            <%= if @mode == "detailed" do %>
              <div class="mt-2 text-sm text-red-700">
                <ul role="list" class="list-disc space-y-1 pl-5">
                  <%= for {field, message} <- @errors do %>
                    <li>
                      <span class="font-medium"><%= humanize_field_name(field, @instance) %>:</span>
                      <%= message %>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp list_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      messages
      |> List.wrap()
      |> Enum.map(fn message -> {field, message} end)
    end)
  end

  # The question's title when it has one, a humanized field name otherwise.
  defp humanize_field_name(field_atom, instance) do
    field_name = to_string(field_atom)

    case Elements.get_question(instance.elements, field_name) do
      %{title: title} when is_binary(title) and title != "" -> title
      _ -> humanize_atom(field_atom)
    end
  end

  defp humanize_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
