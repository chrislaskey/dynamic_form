defmodule DynamicForm.InstanceJsonTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Instance

  defp sample_instance do
    %Instance{
      id: "contact-form",
      title: "Contact Form",
      description: "Get in touch",
      elements: [
        %Instance.Element{
          name: "intro",
          type: "html",
          html: "<h2>Contact Us</h2>"
        },
        %Instance.Question{
          name: "name",
          type: "text",
          title: "Full Name",
          placeholder: "Ada Lovelace",
          isRequired: true,
          validators: [%Instance.Validator{type: "text", minLength: 2}]
        },
        %Instance.Question{
          name: "email",
          type: "text",
          inputType: "email",
          title: "Email",
          description: "We'll never share it",
          isRequired: true,
          validators: [%Instance.Validator{type: "email"}]
        },
        %Instance.Question{
          name: "subject",
          type: "dropdown",
          title: "Subject",
          choices: [{"General", "general"}, {"Support", "support"}],
          visibleIf: "{email} notempty"
        },
        %Instance.Element{
          name: "details-panel",
          type: "panel",
          title: "Details",
          elements: [
            %Instance.Question{
              name: "message",
              type: "comment",
              title: "Message"
            }
          ]
        }
      ],
      metadata: %{"version" => 2}
    }
  end

  describe "JSON round-trip" do
    test "encoding then decoding preserves the instance" do
      instance = sample_instance()

      decoded =
        instance
        |> Jason.encode!()
        |> Instance.decode!()

      assert decoded.id == instance.id
      assert decoded.title == instance.title
      assert decoded.description == instance.description
      assert decoded.metadata == instance.metadata
      assert decoded.elements == instance.elements
    end

    test "round-trips a group's layout type" do
      instance = %Instance{
        id: "group-form",
        elements: [
          %Instance.Element{
            name: "age_range",
            type: "panel",
            title: "Age range",
            groupType: "vertical",
            elements: [%Instance.Question{name: "min", type: "text"}]
          }
        ]
      }

      json = Jason.encode!(instance)

      assert json =~ ~s("groupType":"vertical")

      [decoded] = json |> Instance.decode!() |> Map.get(:elements)

      assert decoded.groupType == "vertical"
    end

    test "a group with no layout type of its own encodes without the key" do
      instance = %Instance{
        id: "group-form",
        elements: [
          %Instance.Element{
            name: "age_range",
            type: "panel",
            elements: [%Instance.Question{name: "min", type: "text"}]
          }
        ]
      }

      refute Jason.encode!(instance) =~ "groupType"
    end

    test "round-trips conditional and rating properties" do
      instance = %Instance{
        id: "props-form",
        elements: [
          %Instance.Question{
            name: "score",
            type: "rating",
            rateMin: 1,
            rateMax: 10,
            rateStep: 1,
            requiredIf: "{other} = true",
            enableIf: "{unlocked} = true",
            visibleIf: "{show} = true",
            defaultValue: 5,
            readOnly: false
          }
        ]
      }

      [decoded] =
        instance
        |> Jason.encode!()
        |> Instance.decode!()
        |> Map.get(:elements)

      assert decoded.rateMin == 1
      assert decoded.rateMax == 10
      assert decoded.rateStep == 1
      assert decoded.requiredIf == "{other} = true"
      assert decoded.enableIf == "{unlocked} = true"
      assert decoded.visibleIf == "{show} = true"
      assert decoded.defaultValue == 5
    end

    test "round-trips image element properties" do
      instance = %Instance{
        id: "image-form",
        elements: [
          %Instance.Element{
            name: "logo",
            type: "image",
            imageLink: "https://example.com/logo.png",
            imageWidth: "100%",
            imageHeight: "auto",
            imageFit: "cover"
          }
        ]
      }

      [decoded] =
        instance
        |> Jason.encode!()
        |> Instance.decode!()
        |> Map.get(:elements)

      assert decoded.imageLink == "https://example.com/logo.png"
      assert decoded.imageWidth == "100%"
      assert decoded.imageHeight == "auto"
      assert decoded.imageFit == "cover"
    end

    test "encoded questions omit nil properties" do
      encoded =
        %Instance.Question{name: "email", type: "text"}
        |> Jason.encode!()
        |> Jason.decode!()

      assert encoded == %{"name" => "email", "type" => "text"}
    end
  end

  describe "decode!/1 - SurveyJS JSON" do
    test "decodes a flat elements list" do
      json = ~s({
        "id": "my-form",
        "title": "My Form",
        "elements": [
          {"type": "text", "name": "email", "inputType": "email", "isRequired": true},
          {"type": "html", "name": "note", "html": "<p>Note</p>"}
        ]
      })

      instance = Instance.decode!(json)

      assert instance.id == "my-form"
      assert instance.title == "My Form"

      assert [
               %Instance.Question{name: "email", inputType: "email", isRequired: true},
               %Instance.Element{name: "note", html: "<p>Note</p>"}
             ] = instance.elements
    end

    test "decodes a map with atom-free string keys" do
      map = %{"id" => "map-form", "elements" => []}
      assert %Instance{id: "map-form", elements: []} = Instance.decode!(map)
    end

    test "generates an id when missing" do
      instance = Instance.decode!(%{"elements" => []})
      assert is_binary(instance.id)
      assert instance.id != ""
    end

    test "flattens all pages into a single elements list" do
      json = ~s({
        "pages": [
          {
            "name": "page1",
            "elements": [{"type": "text", "name": "first_name"}]
          },
          {
            "name": "page2",
            "title": "Employment",
            "elements": [
              {"type": "text", "name": "employer"},
              {"type": "text", "name": "job_title"}
            ]
          }
        ]
      })

      instance = Instance.decode!(json)
      names = Enum.map(instance.elements, & &1.name)

      assert names == ["first_name", "page2-title", "employer", "job_title"]

      # Page titles are preserved as html heading elements
      heading = Enum.find(instance.elements, &(&1.name == "page2-title"))
      assert %Instance.Element{type: "html"} = heading
      assert heading.html =~ "Employment"
    end

    test "escapes html in page titles" do
      json = ~s|{
        "pages": [
          {"name": "p1", "title": "<script>alert(1)</script>", "elements": []}
        ]
      }|

      instance = Instance.decode!(json)
      [heading] = instance.elements
      refute heading.html =~ "<script>"
    end

    test "decodes all recognized question types as questions" do
      types = ~w(text comment dropdown radiogroup boolean file checkbox rating tagbox)

      elements =
        Enum.map(types, fn type ->
          %{"type" => type, "name" => "q-#{type}"}
        end)

      instance = Instance.decode!(%{"id" => "types", "elements" => elements})

      assert Enum.all?(instance.elements, &match?(%Instance.Question{}, &1))
      assert Enum.map(instance.elements, & &1.type) == types
    end

    test "decodes panels recursively" do
      json = ~s({
        "id": "nested",
        "elements": [
          {
            "type": "panel",
            "name": "outer",
            "elements": [
              {
                "type": "panel",
                "name": "inner",
                "elements": [{"type": "text", "name": "deep"}]
              }
            ]
          }
        ]
      })

      instance = Instance.decode!(json)
      [outer] = instance.elements
      [inner] = outer.elements
      [question] = inner.elements

      assert %Instance.Question{name: "deep", type: "text"} = question
    end

    test "falls back to question for unknown types with question-like keys" do
      instance =
        Instance.decode!(%{
          "id" => "fallback",
          "elements" => [
            %{"type" => "customtype", "name" => "a", "choices" => ["x"]},
            %{"type" => "customtype2", "name" => "b", "isRequired" => true},
            %{"type" => "customtype3", "name" => "c"}
          ]
        })

      assert [
               %Instance.Question{name: "a"},
               %Instance.Question{name: "b"},
               %Instance.Element{name: "c"}
             ] = instance.elements
    end
  end

  describe "decode_choices" do
    test "decodes SurveyJS object choices to {text, value} tuples" do
      instance =
        Instance.decode!(%{
          "id" => "choices",
          "elements" => [
            %{
              "type" => "dropdown",
              "name" => "subject",
              "choices" => [
                %{"value" => "general", "text" => "General"},
                %{"value" => "support", "text" => "Support"}
              ]
            }
          ]
        })

      [question] = instance.elements
      assert question.choices == [{"General", "general"}, {"Support", "support"}]
    end

    test "passes through simple string and integer choices" do
      instance =
        Instance.decode!(%{
          "id" => "simple-choices",
          "elements" => [
            %{"type" => "dropdown", "name" => "pick", "choices" => ["Item 1", "Item 2"]},
            %{"type" => "rating", "name" => "num", "choices" => [1, 2, 3]}
          ]
        })

      [strings, numbers] = instance.elements
      assert strings.choices == ["Item 1", "Item 2"]
      assert numbers.choices == [1, 2, 3]
    end
  end

  describe "decode validators" do
    test "decodes SurveyJS validator properties" do
      instance =
        Instance.decode!(%{
          "id" => "validators",
          "elements" => [
            %{
              "type" => "text",
              "name" => "field",
              "validators" => [
                %{"type" => "text", "minLength" => 2, "maxLength" => 100},
                %{"type" => "numeric", "minValue" => 1, "maxValue" => 10},
                %{"type" => "email"},
                %{"type" => "regex", "regex" => "^\\d+$", "text" => "Numbers only"}
              ]
            }
          ]
        })

      [question] = instance.elements

      assert [
               %Instance.Validator{type: "text", minLength: 2, maxLength: 100},
               %Instance.Validator{type: "numeric", minValue: 1, maxValue: 10},
               %Instance.Validator{type: "email"},
               %Instance.Validator{type: "regex", regex: "^\\d+$", text: "Numbers only"}
             ] = question.validators
    end
  end

  describe "datetime fields" do
    test "round-trips inserted_at and updated_at" do
      {:ok, dt, _} = DateTime.from_iso8601("2026-01-15T10:30:00Z")

      instance = %Instance{
        id: "dt-form",
        elements: [],
        inserted_at: dt,
        updated_at: dt
      }

      decoded =
        instance
        |> Jason.encode!()
        |> Instance.decode!()

      assert decoded.inserted_at == dt
      assert decoded.updated_at == dt
    end
  end
end
