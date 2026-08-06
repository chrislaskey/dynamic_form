defmodule DynamicForm.NestedFormsTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Changeset
  alias DynamicForm.Instance
  alias DynamicForm.NestedForms

  defp addresses_question(overrides \\ []) do
    struct!(
      %Instance.Question{
        name: "addresses",
        type: "paneldynamic",
        title: "Addresses",
        templateElements: [
          %Instance.Question{name: "street", type: "text", title: "Street", isRequired: true},
          %Instance.Question{name: "city", type: "text", title: "City", isRequired: true},
          %Instance.Question{name: "unit", type: "text", inputType: "number", title: "Unit"}
        ]
      },
      overrides
    )
  end

  defp instance_with(question) do
    %Instance{
      id: "nested-form",
      elements: [
        %Instance.Question{name: "name", type: "text", isRequired: true},
        question
      ]
    }
  end

  describe "create_changeset/3 - casting" do
    test "casts a list of entries and applies child types" do
      params = %{
        "name" => "Ada",
        "addresses" => [
          %{"street" => "110 Main St", "city" => "Portland", "unit" => "4"},
          %{"street" => "13 Dearborn", "city" => "Boston"}
        ]
      }

      changeset = Changeset.create_changeset(instance_with(addresses_question()), params)

      assert changeset.valid?

      assert [first, second] = Ecto.Changeset.get_change(changeset, :addresses)
      assert first == %{street: "110 Main St", city: "Portland", unit: Decimal.new("4")}
      assert second == %{street: "13 Dearborn", city: "Boston"}
    end

    test "normalizes browser-submitted indexed maps into ordered lists" do
      params = %{
        "name" => "Ada",
        "addresses" => %{
          "__empty__" => "",
          "1" => %{"street" => "Second", "city" => "B"},
          "0" => %{"street" => "First", "city" => "A"},
          "10" => %{"street" => "Last", "city" => "C"}
        }
      }

      changeset = Changeset.create_changeset(instance_with(addresses_question()), params)

      assert changeset.valid?

      streets =
        changeset |> Ecto.Changeset.get_change(:addresses) |> Enum.map(& &1.street)

      assert streets == ["First", "Second", "Last"]
    end

    test "apply_changes yields clean nested data without bookkeeping keys" do
      params = %{
        "name" => "Ada",
        "addresses" => [
          %{"street" => "110 Main St", "city" => "Portland", "_unused_unit" => "", "unit" => ""}
        ]
      }

      changeset = Changeset.create_changeset(instance_with(addresses_question()), params)
      data = Ecto.Changeset.apply_changes(changeset)

      assert data == %{name: "Ada", addresses: [%{street: "110 Main St", city: "Portland"}]}
    end
  end

  describe "create_changeset/3 - validation" do
    test "an invalid entry marks the parent changeset invalid" do
      params = %{
        "name" => "Ada",
        "addresses" => [
          %{"street" => "110 Main St", "city" => "Portland"},
          %{"street" => "", "city" => "Boston"}
        ]
      }

      changeset = Changeset.create_changeset(instance_with(addresses_question()), params)

      refute changeset.valid?
      assert {"is invalid", [validation: :paneldynamic]} = changeset.errors[:addresses]
    end

    test "entry errors are reproducible via entry_changesets/3" do
      params = %{
        "addresses" => [
          %{"street" => "110 Main St", "city" => "Portland"},
          %{"street" => "", "city" => "Boston"}
        ]
      }

      [first, second] = NestedForms.entry_changesets(addresses_question(), params)

      assert first.valid?
      refute second.valid?
      assert {"can't be blank", _} = second.errors[:street]
    end

    test "child validators apply per entry" do
      question =
        addresses_question()
        |> Map.update!(:templateElements, fn elements ->
          elements ++
            [
              %Instance.Question{
                name: "zip",
                type: "text",
                validators: [%Instance.Validator{type: "regex", regex: "^\\d{5}$"}]
              }
            ]
        end)

      params = %{"addresses" => [%{"street" => "x", "city" => "y", "zip" => "abc"}]}

      [child] = NestedForms.entry_changesets(question, params)

      assert {"has invalid format", _} = child.errors[:zip]
    end

    test "isRequired fails an empty entry list" do
      question = addresses_question(isRequired: true)
      instance = instance_with(question)

      changeset = Changeset.create_changeset(instance, %{"name" => "Ada", "addresses" => []})

      refute changeset.valid?
      assert {"can't be blank", [validation: :required]} = changeset.errors[:addresses]
    end

    test "missing paneldynamic params fail isRequired" do
      question = addresses_question(isRequired: true)
      changeset = Changeset.create_changeset(instance_with(question), %{"name" => "Ada"})

      refute changeset.valid?
      assert {"can't be blank", [validation: :required]} = changeset.errors[:addresses]
    end

    test "minPanelCount and maxPanelCount validate entry counts" do
      question = addresses_question(minPanelCount: 2, maxPanelCount: 3)
      instance = instance_with(question)
      entry = %{"street" => "x", "city" => "y"}

      too_few =
        Changeset.create_changeset(instance, %{"name" => "Ada", "addresses" => [entry]})

      refute too_few.valid?
      assert {_, opts} = too_few.errors[:addresses]
      assert opts[:kind] == :min

      too_many =
        Changeset.create_changeset(instance, %{
          "name" => "Ada",
          "addresses" => [entry, entry, entry, entry]
        })

      refute too_many.valid?
      assert {_, opts} = too_many.errors[:addresses]
      assert opts[:kind] == :max

      just_right =
        Changeset.create_changeset(instance, %{"name" => "Ada", "addresses" => [entry, entry]})

      assert just_right.valid?
    end

    test "keyName flags duplicate values with keyDuplicationError" do
      question =
        addresses_question(keyName: "city", keyDuplicationError: "City must be unique.")

      params = %{
        "addresses" => [
          %{"street" => "a", "city" => "Portland"},
          %{"street" => "b", "city" => "Portland"},
          %{"street" => "c", "city" => "Boston"}
        ]
      }

      [first, second, third] = NestedForms.entry_changesets(question, params)

      assert {"City must be unique.", _} = first.errors[:city]
      assert {"City must be unique.", _} = second.errors[:city]
      refute third.errors[:city]

      changeset =
        Changeset.create_changeset(instance_with(question), %{"addresses" => params["addresses"]})

      refute changeset.valid?
    end
  end

  describe "create_changeset/3 - conditional expressions in templates" do
    defp conditional_question do
      %Instance.Question{
        name: "addresses",
        type: "paneldynamic",
        templateElements: [
          %Instance.Question{
            name: "kind",
            type: "dropdown",
            choices: ["Home", "Other"]
          },
          %Instance.Question{
            name: "label",
            type: "text",
            isRequired: true,
            visibleIf: "{panel.kind} = 'Other'"
          }
        ]
      }
    end

    test "{panel.field} references resolve against the entry's own values" do
      instance = %Instance{id: "cond", elements: [conditional_question()]}

      hidden =
        Changeset.create_changeset(instance, %{
          "addresses" => [%{"kind" => "Home", "label" => ""}]
        })

      assert hidden.valid?

      visible =
        Changeset.create_changeset(instance, %{
          "addresses" => [%{"kind" => "Other", "label" => ""}]
        })

      refute visible.valid?
    end

    test "template expressions can reference form-level values" do
      instance = %Instance{
        id: "cond-root",
        elements: [
          %Instance.Question{name: "country", type: "text"},
          %Instance.Question{
            name: "addresses",
            type: "paneldynamic",
            templateElements: [
              %Instance.Question{
                name: "state",
                type: "text",
                requiredIf: "{country} = 'US'"
              }
            ]
          }
        ]
      }

      us =
        Changeset.create_changeset(instance, %{
          "country" => "US",
          "addresses" => [%{"state" => ""}]
        })

      refute us.valid?

      elsewhere =
        Changeset.create_changeset(instance, %{
          "country" => "FR",
          "addresses" => [%{"state" => ""}]
        })

      assert elsewhere.valid?
    end
  end

  describe "nested paneldynamic" do
    test "panels inside panels validate recursively" do
      instance = %Instance{
        id: "nested",
        elements: [
          %Instance.Question{
            name: "contacts",
            type: "paneldynamic",
            templateElements: [
              %Instance.Question{name: "contact_name", type: "text", isRequired: true},
              %Instance.Question{
                name: "phones",
                type: "paneldynamic",
                templateElements: [
                  %Instance.Question{name: "number", type: "text", isRequired: true}
                ]
              }
            ]
          }
        ]
      }

      params = %{
        "contacts" => [
          %{
            "contact_name" => "Ada",
            "phones" => [%{"number" => "555-1234"}, %{"number" => ""}]
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, params)

      refute changeset.valid?

      valid_params = %{
        "contacts" => [
          %{"contact_name" => "Ada", "phones" => [%{"number" => "555-1234"}]}
        ]
      }

      changeset = Changeset.create_changeset(instance, valid_params)
      assert changeset.valid?

      data = Ecto.Changeset.apply_changes(changeset)
      assert data == %{contacts: [%{contact_name: "Ada", phones: [%{number: "555-1234"}]}]}
    end
  end

  describe "new_entry/1" do
    test "seeds template defaults overridden by defaultPanelValue" do
      question =
        addresses_question(
          templateElements: [
            %Instance.Question{name: "street", type: "text", defaultValue: "Unknown"},
            %Instance.Question{name: "city", type: "text", defaultValue: "Portland"}
          ],
          defaultPanelValue: %{"city" => "Boston"}
        )

      assert NestedForms.new_entry(question) == %{
               "street" => "Unknown",
               "city" => "Boston"
             }
    end
  end

  describe "JSON decoding and encoding" do
    test "decodes SurveyJS paneldynamic JSON" do
      json = """
      {
        "id": "contact",
        "elements": [
          {
            "type": "paneldynamic",
            "name": "addresses",
            "title": "Your addresses",
            "templateTitle": "Address #{"{panelIndex}"}",
            "templateElements": [
              {"type": "text", "name": "street", "title": "Street", "isRequired": true},
              {"type": "dropdown", "name": "kind", "choices": ["Home", "Work"]}
            ],
            "panelCount": 1,
            "minPanelCount": 1,
            "maxPanelCount": 5,
            "addPanelText": "Add another address",
            "removePanelText": "Remove this address",
            "confirmDelete": true,
            "confirmDeleteText": "Remove this address?",
            "keyName": "kind",
            "keyDuplicationError": "Kinds must be unique.",
            "defaultPanelValue": {"kind": "Home"}
          }
        ]
      }
      """

      instance = Instance.decode!(json)

      assert [%Instance.Question{type: "paneldynamic"} = question] = instance.elements
      assert question.name == "addresses"
      assert question.templateTitle == "Address {panelIndex}"
      assert question.panelCount == 1
      assert question.minPanelCount == 1
      assert question.maxPanelCount == 5
      assert question.addPanelText == "Add another address"
      assert question.removePanelText == "Remove this address"
      assert question.confirmDelete == true
      assert question.confirmDeleteText == "Remove this address?"
      assert question.keyName == "kind"
      assert question.keyDuplicationError == "Kinds must be unique."
      assert question.defaultPanelValue == %{"kind" => "Home"}

      assert [street, kind] = question.templateElements
      assert %Instance.Question{name: "street", type: "text", isRequired: true} = street
      assert %Instance.Question{name: "kind", type: "dropdown"} = kind
    end

    test "decodes legacy SurveyJS aliases" do
      json = """
      {
        "id": "legacy",
        "elements": [
          {
            "type": "paneldynamic",
            "name": "items",
            "questions": [{"type": "text", "name": "label"}],
            "panelAddText": "Add",
            "panelRemoveText": "Delete"
          }
        ]
      }
      """

      assert [question] = Instance.decode!(json).elements
      assert [%Instance.Question{name: "label"}] = question.templateElements
      assert question.addPanelText == "Add"
      assert question.removePanelText == "Delete"
    end

    test "round-trips through JSON" do
      instance = instance_with(addresses_question(minPanelCount: 1, addPanelText: "Add"))

      decoded = instance |> Jason.encode!() |> Instance.decode!()

      assert decoded == instance
    end
  end

  describe "find_question/2" do
    defp duplicate_names_instance do
      notes_template = [%Instance.Question{name: "note", type: "text"}]

      %Instance{
        id: "dup-names",
        elements: [
          %Instance.Element{
            name: "section",
            type: "panel",
            elements: [
              %Instance.Question{
                name: "contacts",
                type: "paneldynamic",
                templateElements: [
                  %Instance.Question{name: "contact_name", type: "text"},
                  %Instance.Question{
                    name: "notes",
                    type: "paneldynamic",
                    templateElements: notes_template
                  }
                ]
              }
            ]
          },
          %Instance.Question{
            name: "vendors",
            type: "paneldynamic",
            templateElements: [
              %Instance.Question{
                name: "notes",
                type: "paneldynamic",
                templateTitle: "Vendor note",
                templateElements: notes_template
              }
            ]
          }
        ]
      }
    end

    test "resolves paths scope by scope, distinguishing same-named questions" do
      instance = duplicate_names_instance()

      contacts_notes = NestedForms.find_question(instance.elements, "contacts.0.notes")
      vendors_notes = NestedForms.find_question(instance.elements, "vendors.2.notes")

      assert contacts_notes.templateTitle == nil
      assert vendors_notes.templateTitle == "Vendor note"
    end

    test "descends into static panels but never into templates" do
      instance = duplicate_names_instance()

      # "contacts" is inside a panel element — same scope, found
      assert %Instance.Question{name: "contacts"} =
               NestedForms.find_question(instance.elements, "contacts")

      # "notes" only exists inside templates — not in the top-level scope
      assert NestedForms.find_question(instance.elements, "notes") == nil
    end

    test "returns nil for unresolvable paths" do
      instance = duplicate_names_instance()

      assert NestedForms.find_question(instance.elements, "missing") == nil
      assert NestedForms.find_question(instance.elements, "contacts.0.missing") == nil
      assert NestedForms.find_question(instance.elements, "contacts.0.notes.1.missing") == nil
    end
  end

  describe "per-scope names (shadowing)" do
    test "a template field may share a top-level field's name" do
      instance = %Instance{
        id: "shadow",
        elements: [
          %Instance.Question{name: "name", type: "text", isRequired: true},
          %Instance.Question{
            name: "addresses",
            type: "paneldynamic",
            templateElements: [
              %Instance.Question{name: "name", type: "text", isRequired: true},
              %Instance.Question{name: "street", type: "text"}
            ]
          }
        ]
      }

      params = %{
        "name" => "Ada",
        "addresses" => [%{"name" => "Home", "street" => "110 Main St"}]
      }

      changeset = Changeset.create_changeset(instance, params)

      assert changeset.valid?

      data = Ecto.Changeset.apply_changes(changeset)
      assert data.name == "Ada"
      assert [%{name: "Home", street: "110 Main St"}] = data.addresses

      # The entry's blank shadowing field fails its own required check even
      # though the top-level field is filled
      invalid =
        Changeset.create_changeset(instance, %{
          "name" => "Ada",
          "addresses" => [%{"name" => ""}]
        })

      refute invalid.valid?
    end

    test "plain references inside a template resolve innermost-first" do
      instance = %Instance{
        id: "shadow-expr",
        elements: [
          %Instance.Question{name: "kind", type: "text"},
          %Instance.Question{
            name: "addresses",
            type: "paneldynamic",
            templateElements: [
              %Instance.Question{name: "kind", type: "text"},
              %Instance.Question{
                name: "label",
                type: "text",
                isRequired: true,
                visibleIf: "{kind} = 'Other'"
              }
            ]
          }
        ]
      }

      # Top-level kind is 'Other' but the entry's own kind shadows it
      shadowed =
        Changeset.create_changeset(instance, %{
          "kind" => "Other",
          "addresses" => [%{"kind" => "Home", "label" => ""}]
        })

      assert shadowed.valid?

      local =
        Changeset.create_changeset(instance, %{
          "kind" => "Home",
          "addresses" => [%{"kind" => "Other", "label" => ""}]
        })

      refute local.valid?
    end
  end

  describe "entries/1" do
    test "passes lists through, normalizes indexed maps, defaults to empty" do
      assert NestedForms.entries([%{"a" => 1}]) == [%{"a" => 1}]

      assert NestedForms.entries(%{"1" => "b", "0" => "a", "__empty__" => ""}) == ["a", "b"]

      assert NestedForms.entries(nil) == []
      assert NestedForms.entries("") == []
    end
  end
end
