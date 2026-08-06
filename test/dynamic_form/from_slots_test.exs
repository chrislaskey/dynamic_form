defmodule DynamicForm.Instance.FromSlotsTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Instance
  alias DynamicForm.Instance.FromSlots

  defp field(attrs) do
    Map.merge(%{__slot__: :field, inner_block: nil}, Map.new(attrs))
  end

  defp group(attrs) do
    Map.merge(%{__slot__: :group, inner_block: nil}, Map.new(attrs))
  end

  defp convert(fields, groups \\ [], assigns \\ %{}) do
    assigns
    |> Map.merge(%{id: "test-form", field: fields, group: groups})
    |> FromSlots.convert!()
  end

  describe "instance attributes" do
    test "builds an instance with id, title, and description" do
      instance =
        convert(
          [field(type: "text", name: "email")],
          [],
          %{title: "Contact", description: "Get in touch"}
        )

      assert %Instance{id: "test-form", title: "Contact", description: "Get in touch"} = instance
    end
  end

  describe "question conversion" do
    test "maps snake_case slot attrs to SurveyJS-style struct fields" do
      instance =
        convert([
          field(
            type: "text",
            name: "email",
            input_type: "email",
            label: "Email Address",
            placeholder: "you@example.com",
            description: "Work email preferred",
            default: "a@b.co",
            required: true,
            required_if: "{other} notempty",
            read_only: true,
            visible_if: "{subject} = 'support'",
            enable_if: "{unlocked} = true",
            metadata: %{"style" => "wide"}
          )
        ])

      assert [%Instance.Question{} = question] = instance.elements
      assert question.name == "email"
      assert question.type == "text"
      assert question.inputType == "email"
      assert question.title == "Email Address"
      assert question.placeholder == "you@example.com"
      assert question.description == "Work email preferred"
      assert question.defaultValue == "a@b.co"
      assert question.isRequired == true
      assert question.requiredIf == "{other} notempty"
      assert question.readOnly == true
      assert question.visibleIf == "{subject} = 'support'"
      assert question.enableIf == "{unlocked} = true"
      assert question.metadata == %{"style" => "wide"}
      assert question.slot == nil
    end

    test "preserves template order across mixed types" do
      instance =
        convert([
          field(type: "html", name: "intro", html: "<h2>Hi</h2>"),
          field(type: "text", name: "email"),
          field(type: "dropdown", name: "subject", options: ["a", "b"]),
          field(type: "comment", name: "details")
        ])

      assert Enum.map(instance.elements, & &1.name) == ["intro", "email", "subject", "details"]
    end

    test "maps rating attrs" do
      instance =
        convert([field(type: "rating", name: "score", rate_min: 2, rate_max: 8, rate_step: 2)])

      assert [%Instance.Question{rateMin: 2, rateMax: 8, rateStep: 2}] = instance.elements
    end

    test "keeps options as given for choice questions" do
      instance =
        convert([
          field(type: "dropdown", name: "subject", options: [{"Support", "support"}, "other"])
        ])

      assert [%Instance.Question{choices: [{"Support", "support"}, "other"]}] = instance.elements
    end
  end

  describe "validators" do
    test "builds validators from flattened attrs" do
      instance =
        convert([
          field(type: "text", name: "username", min_length: 2, max_length: 20),
          field(type: "text", name: "age", input_type: "number", min: 18, max: 130),
          field(type: "text", name: "slug", pattern: "^[a-z-]+$"),
          field(type: "text", name: "email", format: "email")
        ])

      [username, age, slug, email] = instance.elements

      assert username.validators == [
               %Instance.Validator{type: "text", minLength: 2, maxLength: 20}
             ]

      assert age.validators == [%Instance.Validator{type: "numeric", minValue: 18, maxValue: 130}]
      assert slug.validators == [%Instance.Validator{type: "regex", regex: "^[a-z-]+$"}]
      assert email.validators == [%Instance.Validator{type: "email"}]
    end

    test "accepts explicit validator structs and maps, combined with flattened attrs" do
      instance =
        convert([
          field(
            type: "text",
            name: "code",
            min_length: 4,
            validators: [
              %Instance.Validator{type: "regex", regex: "^[A-Z]+$", text: "Uppercase only"},
              %{type: "text", max_length: 10}
            ]
          )
        ])

      assert [%Instance.Question{validators: validators}] = instance.elements

      assert %Instance.Validator{type: "regex", text: "Uppercase only"} =
               Enum.find(validators, &(&1.type == "regex"))

      assert %Instance.Validator{maxLength: 10} =
               Enum.find(validators, &(&1.maxLength == 10))

      assert %Instance.Validator{minLength: 4} =
               Enum.find(validators, &(&1.minLength == 4))
    end

    test "questions without validation attrs get nil validators" do
      instance = convert([field(type: "text", name: "email")])
      assert [%Instance.Question{validators: nil}] = instance.elements
    end

    test "flattened validators produce a working changeset" do
      instance =
        convert([field(type: "text", name: "username", required: true, min_length: 3)])

      changeset = DynamicForm.Changeset.create_changeset(instance, %{"username" => "ab"})
      refute changeset.valid?

      changeset = DynamicForm.Changeset.create_changeset(instance, %{"username" => "abc"})
      assert changeset.valid?
    end

    test "raises on unknown format" do
      assert_raise ArgumentError, ~r/unknown format "phone"/, fn ->
        convert([field(type: "text", name: "phone", format: "phone")])
      end
    end
  end

  describe "elements" do
    test "converts html fields with an html attribute" do
      instance = convert([field(type: "html", name: "intro", html: "<h2>Hi</h2>")])
      assert [%Instance.Element{type: "html", html: "<h2>Hi</h2>", slot: nil}] = instance.elements
    end

    test "auto-generates names for elements without one" do
      instance =
        convert([
          field(type: "html", html: "<p>a</p>"),
          field(type: "text", name: "email"),
          field(type: "image", src: "/logo.png")
        ])

      assert Enum.map(instance.elements, & &1.name) == ["element-1", "email", "element-3"]
    end

    test "maps image attrs" do
      instance =
        convert([
          field(type: "image", name: "logo", src: "/logo.png", width: "300px", fit: "cover")
        ])

      assert [
               %Instance.Element{
                 type: "image",
                 imageLink: "/logo.png",
                 imageWidth: "300px",
                 imageFit: "cover"
               }
             ] = instance.elements
    end
  end

  describe "slot bodies" do
    test "keeps the raw slot entry when a body is present" do
      entry = field(type: "html", name: "intro", inner_block: fn _, _ -> "content" end)
      instance = convert([entry])

      assert [%Instance.Element{type: "html", slot: ^entry}] = instance.elements
    end

    test "keeps slot entries on questions with bodies" do
      entry = field(type: "text", name: "amount", inner_block: fn _, _ -> "control" end)
      instance = convert([entry])

      assert [%Instance.Question{slot: ^entry}] = instance.elements
    end

    test "strip_slots removes slot entries recursively and enables definition equality" do
      build = fn closure ->
        convert(
          [
            field(type: "text", name: "amount", inner_block: closure),
            field(type: "text", name: "street", group: "address", inner_block: closure)
          ],
          [group(name: "address", title: "Address")]
        )
      end

      # Different closures (e.g. captured assigns changed) — unequal as-is,
      # equal once stripped
      a = build.(fn _, _ -> "one" end)
      b = build.(fn _, _ -> "two" end)

      refute a == b
      assert Instance.strip_slots(a) == Instance.strip_slots(b)

      stripped = Instance.strip_slots(a)
      [question, panel] = stripped.elements
      assert question.slot == nil
      assert [%Instance.Question{slot: nil}] = panel.elements
    end

    test "instances with slot bodies JSON-encode without them" do
      instance =
        convert([field(type: "text", name: "amount", inner_block: fn _, _ -> "x" end)])

      json = Jason.encode!(instance)
      decoded = Jason.decode!(json)

      assert [%{"name" => "amount", "type" => "text"} = question] = decoded["elements"]
      refute Map.has_key?(question, "slot")
      refute Map.has_key?(question, "inner_block")
    end
  end

  describe "groups" do
    test "emits the panel at the position of its first member with all members" do
      instance =
        convert(
          [
            field(type: "text", name: "email"),
            field(type: "text", name: "street", group: "address"),
            field(type: "text", name: "terms"),
            field(type: "text", name: "city", group: "address")
          ],
          [group(name: "address", title: "Shipping Address", visible_if: "{ship} = true")]
        )

      assert Enum.map(instance.elements, & &1.name) == ["email", "address", "terms"]

      panel = Enum.at(instance.elements, 1)
      assert %Instance.Element{type: "panel", title: "Shipping Address"} = panel
      assert panel.visibleIf == "{ship} = true"
      assert Enum.map(panel.elements, & &1.name) == ["street", "city"]
    end

    test "grouped questions are included in the changeset" do
      instance =
        convert(
          [field(type: "text", name: "street", group: "address", required: true)],
          [group(name: "address")]
        )

      changeset = DynamicForm.Changeset.create_changeset(instance, %{})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :street)
    end
  end

  describe "validation errors" do
    test "raises when a question has no name" do
      assert_raise ArgumentError, ~r/requires a name/, fn ->
        convert([field(type: "text")])
      end
    end

    test "raises on unknown type" do
      assert_raise ArgumentError, ~r/unknown type "carousel"/, fn ->
        convert([field(type: "carousel", name: "x")])
      end
    end

    test "raises on duplicate names, including group names" do
      assert_raise ArgumentError, ~r/duplicate names.*email/s, fn ->
        convert([field(type: "text", name: "email"), field(type: "comment", name: "email")])
      end

      assert_raise ArgumentError, ~r/group name="address".*collides/s, fn ->
        convert(
          [
            field(type: "text", name: "address"),
            field(type: "text", name: "street", group: "address")
          ],
          [group(name: "address")]
        )
      end
    end

    test "raises when a choice question has no options" do
      assert_raise ArgumentError, ~r/requires an options list/, fn ->
        convert([field(type: "dropdown", name: "subject")])
      end
    end

    test "raises when a custom field has no body" do
      assert_raise ArgumentError, ~r/requires a slot body/, fn ->
        convert([field(type: "custom", name: "summary")])
      end
    end

    test "raises when an html field has neither html attr nor body, or both" do
      assert_raise ArgumentError, ~r/requires either an html attribute or a slot body/, fn ->
        convert([field(type: "html", name: "intro")])
      end

      assert_raise ArgumentError, ~r/cannot have both/, fn ->
        convert([
          field(type: "html", name: "intro", html: "<p>a</p>", inner_block: fn _, _ -> "b" end)
        ])
      end
    end

    test "raises when an image field has no src" do
      assert_raise ArgumentError, ~r/requires a src/, fn ->
        convert([field(type: "image", name: "logo")])
      end
    end

    test "raises when a field references an undeclared group" do
      assert_raise ArgumentError, ~r/references group "address"/, fn ->
        convert([field(type: "text", name: "street", group: "address")])
      end
    end

    test "raises on invalid validators entries" do
      assert_raise ArgumentError, ~r/invalid entry in :validators/, fn ->
        convert([field(type: "text", name: "x", validators: ["email"])])
      end
    end
  end

  describe "nested form conversion" do
    defp nested(attrs) do
      Map.merge(%{__slot__: :nested, inner_block: nil}, Map.new(attrs))
    end

    defp convert_nested(fields, groups, nesteds, assigns \\ %{}) do
      assigns
      |> Map.merge(%{id: "test-form", field: fields, group: groups, nested: nesteds})
      |> FromSlots.convert!()
    end

    test "collects nested= fields into a paneldynamic question's template" do
      instance =
        convert_nested(
          [
            field(type: "text", name: "name"),
            field(type: "text", name: "street", nested: "addresses"),
            field(type: "text", name: "city", nested: "addresses")
          ],
          [],
          [nested(name: "addresses", title: "Addresses")]
        )

      assert [%Instance.Question{name: "name"}, %Instance.Question{} = question] =
               instance.elements

      assert question.type == "paneldynamic"
      assert question.name == "addresses"
      assert question.title == "Addresses"
      assert Enum.map(question.templateElements, & &1.name) == ["street", "city"]
    end

    test "maps <:nested> attrs to SurveyJS-style question fields" do
      instance =
        convert_nested(
          [field(type: "text", name: "street", nested: "addresses")],
          [],
          [
            nested(
              name: "addresses",
              title: "Addresses",
              description: "All addresses on file",
              entry_title: "Address {panelIndex}",
              entries: 1,
              min_entries: 1,
              max_entries: 4,
              add_text: "Add address",
              remove_text: "Drop",
              no_entries_text: "None yet",
              confirm_delete: true,
              confirm_text: "Sure?",
              key: "street",
              key_error: "Must be unique",
              default: [%{"street" => "110 Main St"}],
              default_entry: %{"street" => "TBD"},
              required: true,
              visible_if: "{has_address} = true"
            )
          ]
        )

      assert [%Instance.Question{} = question] = instance.elements
      assert question.description == "All addresses on file"
      assert question.templateTitle == "Address {panelIndex}"
      assert question.panelCount == 1
      assert question.minPanelCount == 1
      assert question.maxPanelCount == 4
      assert question.addPanelText == "Add address"
      assert question.removePanelText == "Drop"
      assert question.noEntriesText == "None yet"
      assert question.confirmDelete == true
      assert question.confirmDeleteText == "Sure?"
      assert question.keyName == "street"
      assert question.keyDuplicationError == "Must be unique"
      assert question.defaultValue == [%{"street" => "110 Main St"}]
      assert question.defaultPanelValue == %{"street" => "TBD"}
      assert question.isRequired == true
      assert question.visibleIf == "{has_address} = true"
    end

    test "renders the nested question at the position of its first member field" do
      instance =
        convert_nested(
          [
            field(type: "text", name: "before"),
            field(type: "text", name: "street", nested: "addresses"),
            field(type: "text", name: "after"),
            field(type: "text", name: "city", nested: "addresses")
          ],
          [],
          [nested(name: "addresses")]
        )

      assert Enum.map(instance.elements, & &1.name) == ["before", "addresses", "after"]
    end

    test "group inside a nested form becomes a panel in the template" do
      instance =
        convert_nested(
          [
            field(type: "text", name: "kind", nested: "addresses"),
            field(type: "text", name: "street", nested: "addresses", group: "geo"),
            field(type: "text", name: "city", nested: "addresses", group: "geo")
          ],
          [group(name: "geo", title: "Location", nested: "addresses")],
          [nested(name: "addresses")]
        )

      assert [%Instance.Question{templateElements: [kind, panel]}] = instance.elements
      assert kind.name == "kind"
      assert %Instance.Element{type: "panel", name: "geo", title: "Location"} = panel
      assert Enum.map(panel.elements, & &1.name) == ["street", "city"]
    end

    test "nested form inside a group renders within the panel" do
      instance =
        convert_nested(
          [
            field(type: "text", name: "company", group: "employment"),
            field(type: "text", name: "role", nested: "positions")
          ],
          [group(name: "employment", title: "Employment")],
          [nested(name: "positions", group: "employment")]
        )

      assert [%Instance.Element{type: "panel", elements: [company, positions]}] =
               instance.elements

      assert company.name == "company"
      assert %Instance.Question{type: "paneldynamic", name: "positions"} = positions
      assert Enum.map(positions.templateElements, & &1.name) == ["role"]
    end

    test "nested forms nest recursively" do
      instance =
        convert_nested(
          [
            field(type: "text", name: "contact_name", nested: "contacts"),
            field(type: "text", name: "number", nested: "phones")
          ],
          [],
          [nested(name: "contacts"), nested(name: "phones", nested: "contacts")]
        )

      assert [%Instance.Question{name: "contacts", templateElements: [contact_name, phones]}] =
               instance.elements

      assert contact_name.name == "contact_name"
      assert %Instance.Question{type: "paneldynamic", name: "phones"} = phones
      assert Enum.map(phones.templateElements, & &1.name) == ["number"]
    end

    test "field names are unique per scope, so schema-mirroring names coexist" do
      instance =
        convert_nested(
          [
            field(type: "text", name: "name"),
            field(type: "text", name: "name", nested: "addresses")
          ],
          [],
          [nested(name: "addresses")]
        )

      assert [top, %Instance.Question{templateElements: [inner]}] = instance.elements
      assert top.name == "name"
      assert inner.name == "name"
    end

    test "slot bodies on template fields are preserved" do
      body = fn _, _ -> "custom" end

      instance =
        convert_nested(
          [field(type: "text", name: "street", nested: "addresses", inner_block: body)],
          [],
          [nested(name: "addresses")]
        )

      assert [%Instance.Question{templateElements: [street]}] = instance.elements
      assert street.slot[:inner_block] == body
    end
  end

  describe "nested form validation errors" do
    test "raises when a field references an undeclared nested form" do
      assert_raise ArgumentError, ~r/references nested "addresses"/, fn ->
        convert([field(type: "text", name: "street", nested: "addresses")])
      end
    end

    test "raises when a <:nested> has no name" do
      assert_raise ArgumentError, ~r/<:nested> requires a name/, fn ->
        convert_nested([field(type: "text", name: "x")], [], [nested(title: "Oops")])
      end
    end

    test "raises when a <:nested> has no members" do
      assert_raise ArgumentError, ~r/has no members/, fn ->
        convert_nested([field(type: "text", name: "x")], [], [nested(name: "addresses")])
      end
    end

    test "raises on duplicate <:nested> declarations" do
      assert_raise ArgumentError, ~r/duplicate <:nested> declarations: notes/, fn ->
        convert_nested(
          [
            field(type: "text", name: "a", nested: "notes"),
            field(type: "text", name: "b", nested: "vendors")
          ],
          [],
          [
            nested(name: "notes"),
            nested(name: "notes", nested: "vendors"),
            nested(name: "vendors")
          ]
        )
      end
    end

    test "raises on duplicate names within one scope" do
      assert_raise ArgumentError, ~r/duplicate names in nested form "addresses": street/, fn ->
        convert_nested(
          [
            field(type: "text", name: "street", nested: "addresses"),
            field(type: "comment", name: "street", nested: "addresses")
          ],
          [],
          [nested(name: "addresses")]
        )
      end
    end

    test "raises when group scope and member scope disagree" do
      # Group is in the nested scope; member forgot the nested attr
      assert_raise ArgumentError, ~r/"zip" is in group "geo".*declares no nested scope/s, fn ->
        convert_nested(
          [
            field(type: "text", name: "street", nested: "addresses", group: "geo"),
            field(type: "text", name: "zip", group: "geo")
          ],
          [group(name: "geo", nested: "addresses")],
          [nested(name: "addresses")]
        )
      end

      # Group is top-level; member declares a nested scope
      assert_raise ArgumentError, ~r/"street" is in group "geo".*no nested scope.*but/s, fn ->
        convert_nested(
          [field(type: "text", name: "street", nested: "addresses", group: "geo")],
          [group(name: "geo")],
          [nested(name: "addresses")]
        )
      end
    end

    test "raises on cyclic nested references" do
      assert_raise ArgumentError, ~r/cyclic <:nested> references/, fn ->
        convert_nested(
          [
            field(type: "text", name: "a", nested: "outer"),
            field(type: "text", name: "b", nested: "inner")
          ],
          [],
          [nested(name: "outer", nested: "inner"), nested(name: "inner", nested: "outer")]
        )
      end
    end

    test "raises on a self-referencing nested form" do
      assert_raise ArgumentError, ~r/cyclic <:nested> references/, fn ->
        convert_nested(
          [field(type: "text", name: "a", nested: "loop")],
          [],
          [nested(name: "loop", nested: "loop")]
        )
      end
    end

    test "raises on file uploads inside nested forms" do
      assert_raise ArgumentError, ~r/file uploads inside nested forms/, fn ->
        convert_nested(
          [field(type: "file", name: "doc", nested: "addresses")],
          [],
          [nested(name: "addresses")]
        )
      end
    end
  end
end
