defmodule DynamicForm.Instance.Elements do
  @moduledoc """
  Queries over a form definition's element tree.

  All functions share the same scope rule: static panels
  (`Instance.Element` containers) are transparent — their questions belong to
  the enclosing scope — while a `paneldynamic` question's `templateElements`
  form their own scope and are never descended into.

  Internal module — not part of the public API.
  """

  alias DynamicForm.Instance

  @doc """
  Flat list of every question in the tree, in render order.

  A `paneldynamic` question appears as a single entry; its template questions
  are not included.
  """
  def list_questions(elements) when is_list(elements) do
    Enum.flat_map(elements, fn element ->
      case element do
        %Instance.Question{} = question ->
          [question]

        %Instance.Element{elements: nested_elements} when is_list(nested_elements) ->
          list_questions(nested_elements)

        %Instance.Element{} ->
          []
      end
    end)
  end

  @doc """
  The first question with the given name, or `nil`.
  """
  def get_question(elements, name) when is_list(elements) do
    Enum.find_value(elements, fn element ->
      case element do
        %Instance.Question{name: ^name} = question ->
          question

        %Instance.Element{elements: nested_elements} when is_list(nested_elements) ->
          get_question(nested_elements, name)

        _ ->
          nil
      end
    end)
  end

  def get_question(_, _), do: nil

  @doc """
  The `paneldynamic` question at a dot-separated entry path, or `nil`.

  Path segments alternate question names and entry indexes (`"addresses"`,
  or `"contacts.0.phones"` when nested). Each name resolves within its own
  scope — the given elements for the first segment, then each matched
  question's `templateElements` — so questions in different scopes may
  share a name.
  """
  def get_question_by_path(elements, path) when is_binary(path) do
    get_question_by_path(elements, String.split(path, "."))
  end

  def get_question_by_path(elements, [name]), do: get_paneldynamic(elements, name)

  def get_question_by_path(elements, [name, _index | rest]) do
    case get_paneldynamic(elements, name) do
      %Instance.Question{templateElements: template} when is_list(template) ->
        get_question_by_path(template, rest)

      _ ->
        nil
    end
  end

  defp get_paneldynamic(elements, name) when is_list(elements) do
    Enum.find_value(elements, fn
      %Instance.Question{type: "paneldynamic", name: ^name} = question -> question
      %Instance.Element{elements: nested} when is_list(nested) -> get_paneldynamic(nested, name)
      _ -> nil
    end)
  end

  defp get_paneldynamic(_elements, _name), do: nil

  @doc """
  Map of question name to question for one scope.

  When two questions share a name, the later one wins.
  """
  def questions_by_name(elements) when is_list(elements) do
    Enum.reduce(elements, %{}, fn
      %Instance.Question{} = question, acc ->
        Map.put(acc, question.name, question)

      %Instance.Element{elements: nested}, acc when is_list(nested) ->
        Map.merge(acc, questions_by_name(nested))

      _element, acc ->
        acc
    end)
  end

  def questions_by_name(_elements), do: %{}

  @doc """
  Flat list of every `file` question in the tree.
  """
  def list_file_questions(elements) when is_list(elements) do
    Enum.flat_map(elements, fn element ->
      case element do
        %Instance.Question{type: "file"} ->
          [element]

        %Instance.Element{elements: nested_elements} when is_list(nested_elements) ->
          list_file_questions(nested_elements)

        _ ->
          []
      end
    end)
  end
end
