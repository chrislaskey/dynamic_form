defmodule DynamicForm.Instance.ElementsTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Instance
  alias DynamicForm.Instance.Elements

  defp question(name, attrs \\ []) do
    struct!(Instance.Question, Keyword.merge([name: name, type: "text"], attrs))
  end

  defp panel(name, elements) do
    %Instance.Element{name: name, type: "panel", elements: elements}
  end

  defp paneldynamic(name, template, attrs \\ []) do
    question(name, Keyword.merge([type: "paneldynamic", templateElements: template], attrs))
  end

  describe "list_questions/1" do
    test "returns questions in order" do
      elements = [question("a"), question("b")]

      assert Elements.list_questions(elements) == elements
    end

    test "descends into panels (panels are transparent)" do
      inner = question("inner")
      elements = [question("a"), panel("group", [inner, panel("deeper", [question("b")])])]

      assert [%{name: "a"}, %{name: "inner"}, %{name: "b"}] =
               Elements.list_questions(elements)
    end

    test "skips non-question elements without children" do
      elements = [%Instance.Element{name: "note", type: "html", html: "<p>Hi</p>"}, question("a")]

      assert [%{name: "a"}] = Elements.list_questions(elements)
    end

    test "includes a paneldynamic as one question without flattening its template" do
      elements = [paneldynamic("contacts", [question("phone")])]

      assert [%Instance.Question{name: "contacts", type: "paneldynamic"}] =
               Elements.list_questions(elements)
    end

    test "returns an empty list for no elements" do
      assert Elements.list_questions([]) == []
    end
  end

  describe "get_question/2" do
    test "finds a question of any type by name" do
      boolean = question("subscribed", type: "boolean")

      assert Elements.get_question([question("a"), boolean], "subscribed") == boolean
    end

    test "finds a question inside a panel" do
      inner = question("inner")

      assert Elements.get_question([panel("group", [inner])], "inner") == inner
    end

    test "returns the first match" do
      first = question("dup", title: "First")
      second = question("dup", title: "Second")

      assert Elements.get_question([first, second], "dup") == first
    end

    test "does not descend into paneldynamic templates" do
      elements = [paneldynamic("contacts", [question("phone")])]

      assert Elements.get_question(elements, "phone") == nil
    end

    test "returns nil when missing or when elements is not a list" do
      assert Elements.get_question([question("a")], "missing") == nil
      assert Elements.get_question(nil, "a") == nil
    end
  end

  describe "get_question_by_path/2" do
    setup do
      notes = paneldynamic("notes", [question("body")])
      contacts = paneldynamic("contacts", [question("phone"), notes])

      elements = [
        question("email"),
        panel("group", [contacts]),
        paneldynamic("vendors", [paneldynamic("notes", [question("vendor_note")])])
      ]

      %{elements: elements, contacts: contacts, notes: notes}
    end

    test "resolves a single-segment path", %{elements: elements, contacts: contacts} do
      assert Elements.get_question_by_path(elements, "contacts") == contacts
      assert Elements.get_question_by_path(elements, ["contacts"]) == contacts
    end

    test "resolves a nested path through entry indexes", %{elements: elements, notes: notes} do
      assert Elements.get_question_by_path(elements, "contacts.0.notes") == notes
      assert Elements.get_question_by_path(elements, ["contacts", "3", "notes"]) == notes
    end

    test "each segment resolves in its own scope", %{elements: elements} do
      assert %Instance.Question{templateElements: [%{name: "vendor_note"}]} =
               Elements.get_question_by_path(elements, "vendors.0.notes")
    end

    test "only matches paneldynamic questions", %{elements: elements} do
      assert Elements.get_question_by_path(elements, "email") == nil
    end

    test "finds a paneldynamic inside a static panel", %{
      elements: elements,
      contacts: contacts
    } do
      assert Elements.get_question_by_path(elements, "contacts") == contacts
    end

    test "returns nil for unresolvable paths", %{elements: elements} do
      assert Elements.get_question_by_path(elements, "missing") == nil
      assert Elements.get_question_by_path(elements, "contacts.0.missing") == nil
      assert Elements.get_question_by_path(elements, "email.0.anything") == nil
    end
  end

  describe "questions_by_name/1" do
    test "maps names to questions, panels transparent" do
      a = question("a")
      inner = question("inner")

      assert Elements.questions_by_name([a, panel("group", [inner])]) ==
               %{"a" => a, "inner" => inner}
    end

    test "does not include paneldynamic template questions" do
      contacts = paneldynamic("contacts", [question("phone")])

      assert Elements.questions_by_name([contacts]) == %{"contacts" => contacts}
    end

    test "later duplicate names win" do
      first = question("dup", title: "First")
      second = question("dup", title: "Second")

      assert Elements.questions_by_name([first, second]) == %{"dup" => second}
    end

    test "returns an empty map for empty or non-list input" do
      assert Elements.questions_by_name([]) == %{}
      assert Elements.questions_by_name(nil) == %{}
    end
  end

  describe "list_file_questions/1" do
    test "returns only file questions, descending into panels" do
      upload = question("upload", type: "file")
      nested_upload = question("nested_upload", type: "file")

      elements = [question("a"), upload, panel("group", [nested_upload, question("b")])]

      assert Elements.list_file_questions(elements) == [upload, nested_upload]
    end

    test "does not descend into paneldynamic templates" do
      elements = [paneldynamic("contacts", [question("attachment", type: "file")])]

      assert Elements.list_file_questions(elements) == []
    end

    test "returns an empty list when there are no file questions" do
      assert Elements.list_file_questions([question("a")]) == []
    end
  end
end
