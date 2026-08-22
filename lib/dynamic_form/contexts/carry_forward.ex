defmodule DynamicForm.CarryForward do
  @moduledoc """
  SurveyJS "carry forward": a question whose choices come from another
  question — one choice per entry of a nested form, or another choice
  question's own choices, optionally narrowed by `choicesFromQuestionMode`.

  One function for each side of the lifecycle:

    * `resolve_choices/2` — at render time, a question's effective choices
      (its own when no carry-forward is declared).
    * `prune_values/4` — at cast time, drop stored values the source no
      longer offers.

  Internal module — not part of the public API.
  """

  alias DynamicForm.{Instance, NestedForms}

  @doc """
  A question's choices as `{text, value}` tuples: its own `choices`, or —
  when it declares `choicesFromQuestion` — one choice per entry of the
  source question.

  The source name resolves innermost-first, matching how `{field}`
  expressions scope inside a template: the enclosing entry's values first,
  then form-level. That is what lets a field inside one entry list "this
  entry's own children" as well as a top-level nested form's entries.

  Reads from `opts`: `:questions` and `:entry_questions` (name → question
  maps for the form and enclosing entry scopes), `:form_data` and
  `:entry_data` (their current values).
  """
  def resolve_choices(%Instance.Question{choicesFromQuestion: nil} = question, _opts) do
    normalize_choices(question.choices)
  end

  def resolve_choices(%Instance.Question{} = question, opts) do
    case get_source_question(question.choicesFromQuestion, opts) do
      %Instance.Question{type: "paneldynamic"} -> carried_from_entries(question, opts)
      %Instance.Question{} = source -> carried_from_choices(source, question, opts)
      nil -> carried_from_entries(question, opts)
    end
  end

  @doc """
  Drops values of a carried-forward question that its source no longer
  offers — the entry they referenced was deleted, or the option was taken
  out of the definition. Runs before `validate_required` so emptying a
  required field errors as it would have.

  A source that resolves to *nothing* still prunes: keeping ids for entries
  the same submission deletes would hand the application a payload that
  contradicts itself. Only a source we cannot observe is left alone — see
  `carried_source_values/3`.

  `params` carries entry-local values merged over form-level ones, so a
  source name resolves the same way it does when rendering.
  """
  def prune_values(changeset, questions, params, opts) do
    scope = questions ++ Keyword.get(opts, :root_questions, [])

    questions
    |> Enum.filter(&(&1.choicesFromQuestion != nil))
    |> Enum.reduce(changeset, fn question, acc ->
      case carried_source_values(question, scope, params) do
        :unobservable -> acc
        valid -> prune_field(acc, question, valid)
      end
    end)
  end

  # Rendering

  # The source question, innermost-first: a question in the enclosing entry's
  # template shadows a form-level one of the same name.
  defp get_source_question(name, opts) do
    entry_scope = Keyword.get(opts, :entry_questions) || %{}
    form_scope = Keyword.get(opts, :questions) || %{}

    Map.get(entry_scope, name) || Map.get(form_scope, name)
  end

  # One choice per entry of a nested form.
  defp carried_from_entries(question, opts) do
    case get_source_value(question.choicesFromQuestion, opts) do
      nil ->
        []

      value ->
        value
        |> NestedForms.list_entries()
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
          |> get_source_value(opts)
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

  defp get_source_value(name, opts) do
    entry_scope = Keyword.get(opts, :entry_data) || %{}
    form_scope = Keyword.get(opts, :form_data) || %{}

    get_field_value(entry_scope, name) || get_field_value(form_scope, name)
  end

  # Values reach here as applied changeset data (atom keys) in the managed
  # lifecycle, and as raw params (string keys) when render-only mode renders
  # against a form the parent built from params. Read both rather than
  # silently finding nothing.
  defp get_field_value(map, name) when is_map(map) and is_binary(name) do
    case Map.fetch(map, String.to_atom(name)) do
      {:ok, value} -> value
      :error -> Map.get(map, name)
    end
  end

  defp get_field_value(_map, _name), do: nil

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
    get_field_value(entry, NestedForms.id_field())
  end

  defp carried_value(entry, %Instance.Question{choiceValuesFromQuestion: field}) do
    get_field_value(entry, field)
  end

  defp carried_text(entry, index, %Instance.Question{choiceTextsFromQuestion: template})
       when is_binary(template) do
    if String.contains?(template, "{") do
      interpolate_choice_text(template, entry, index)
    else
      get_field_value(entry, template)
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

    values = Enum.map(fields, &to_string(get_field_value(entry, &1)))

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

  # Pruning

  # The values a carried-forward field may hold: one per entry of a nested
  # source, or the source's own choice values when it is another choice
  # question (narrowed by choicesFromQuestionMode).
  #
  # `:unobservable` means we can't tell what the source offers, so the stored
  # values stay: either the definition has no such question (a hand-edited
  # JSON definition — declarative mode raises long before this), or it has one
  # but this submission doesn't carry its values, as when `visible_if` hides
  # it. An empty source is not unobservable: emptying it is a user action.
  defp carried_source_values(question, scope, params) do
    case Enum.find(scope, &(&1.name == question.choicesFromQuestion)) do
      nil -> :unobservable
      %Instance.Question{type: "paneldynamic"} -> entry_source_values(question, params)
      %Instance.Question{} = source -> choice_source_values(question, source, params)
    end
  end

  defp entry_source_values(question, params) do
    value_field = question.choiceValuesFromQuestion || NestedForms.id_field()

    entries =
      params
      |> Map.get(question.choicesFromQuestion)
      |> NestedForms.list_entries()

    values =
      entries
      |> Enum.map(&entry_value(&1, value_field))
      |> Enum.reject(&(&1 in [nil, ""]))

    cond do
      not Map.has_key?(params, question.choicesFromQuestion) -> :unobservable
      # Entries are present but carry no value to compare against — the
      # submission omitted the source and its values came back from the
      # initial data, which holds no ids. Not the same as an empty source.
      entries != [] and values == [] -> :unobservable
      true -> values
    end
  end

  defp choice_source_values(question, source, params) do
    values =
      source.choices
      |> List.wrap()
      |> Enum.map(fn
        {_text, value} -> to_string(value)
        value -> to_string(value)
      end)

    cond do
      question.choicesFromQuestionMode not in ["selected", "unselected"] ->
        values

      not Map.has_key?(params, source.name) ->
        :unobservable

      true ->
        selected =
          params
          |> Map.get(source.name)
          |> List.wrap()
          |> Enum.map(&to_string/1)

        mode = question.choicesFromQuestionMode
        Enum.filter(values, &(&1 in selected == (mode == "selected")))
    end
  end

  defp entry_value(entry, field) when is_map(entry) do
    case Map.get(entry, field) do
      nil -> entry |> Map.get(String.to_atom(field)) |> stringify_value()
      value -> stringify_value(value)
    end
  end

  defp entry_value(_entry, _field), do: nil

  defp stringify_value(nil), do: nil
  defp stringify_value(value), do: to_string(value)

  defp prune_field(changeset, question, valid) do
    field = String.to_atom(question.name)

    case Ecto.Changeset.fetch_change(changeset, field) do
      {:ok, values} when is_list(values) ->
        Ecto.Changeset.put_change(
          changeset,
          field,
          Enum.filter(values, &(to_string(&1) in valid))
        )

      {:ok, value} ->
        if to_string(value) in valid,
          do: changeset,
          else: Ecto.Changeset.delete_change(changeset, field)

      :error ->
        changeset
    end
  end
end
