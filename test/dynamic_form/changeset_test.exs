defmodule DynamicForm.ChangesetTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Changeset
  alias DynamicForm.Instance

  defp payment_instance do
    %Instance{
      id: "payment-form",
      title: "Payment Form",
      elements: [
        %Instance.Question{
          name: "payment_method",
          type: "dropdown",
          title: "Payment Method",
          isRequired: true,
          choices: [
            {"Credit Card", "credit_card"},
            {"Bank Transfer", "bank_transfer"}
          ]
        },
        %Instance.Question{
          name: "card_number",
          type: "text",
          title: "Card Number",
          isRequired: true,
          visibleIf: "{payment_method} = 'credit_card'"
        },
        %Instance.Question{
          name: "account_number",
          type: "text",
          title: "Account Number",
          isRequired: true,
          visibleIf: "{payment_method} = 'bank_transfer'"
        }
      ]
    }
  end

  describe "create_changeset/2 - basic casting" do
    test "casts question values with correct types" do
      instance = %Instance{
        id: "types-form",
        elements: [
          %Instance.Question{name: "name", type: "text"},
          %Instance.Question{name: "age", type: "text", inputType: "number"},
          %Instance.Question{name: "bio", type: "comment"},
          %Instance.Question{name: "newsletter", type: "boolean"},
          %Instance.Question{name: "score", type: "rating"},
          %Instance.Question{name: "toppings", type: "checkbox"},
          %Instance.Question{name: "tags", type: "tagbox"}
        ]
      }

      params = %{
        "name" => "Ada",
        "age" => "36",
        "bio" => "Mathematician",
        "newsletter" => "true",
        "score" => "5",
        "toppings" => ["cheese"],
        "tags" => ["a", "b"]
      }

      changeset = Changeset.create_changeset(instance, params)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "Ada"
      assert Ecto.Changeset.get_change(changeset, :age) == Decimal.new("36")
      assert Ecto.Changeset.get_change(changeset, :newsletter) == true
      assert Ecto.Changeset.get_change(changeset, :score) == 5
      assert Ecto.Changeset.get_change(changeset, :toppings) == ["cheese"]
      assert Ecto.Changeset.get_change(changeset, :tags) == ["a", "b"]
    end

    test "extracts questions nested inside panels" do
      instance = %Instance{
        id: "panel-form",
        elements: [
          %Instance.Element{
            name: "address-panel",
            type: "panel",
            elements: [
              %Instance.Question{name: "city", type: "text", isRequired: true}
            ]
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, %{})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:city]
    end
  end

  describe "create_changeset/2 - conditional required (visibleIf)" do
    test "validates required field when visible" do
      params = %{"payment_method" => "credit_card", "card_number" => ""}
      changeset = Changeset.create_changeset(payment_instance(), params)

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:card_number]
    end

    test "skips required validation for hidden fields" do
      params = %{"payment_method" => "bank_transfer", "account_number" => "12345678"}
      changeset = Changeset.create_changeset(payment_instance(), params)

      assert changeset.valid?
      refute changeset.errors[:card_number]
    end

    test "always-visible required fields are always validated" do
      changeset = Changeset.create_changeset(payment_instance(), %{})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:payment_method]
      refute changeset.errors[:card_number]
      refute changeset.errors[:account_number]
    end

    test "compound visibleIf expressions gate required validation" do
      instance = %Instance{
        id: "compound-form",
        elements: [
          %Instance.Question{name: "type", type: "dropdown"},
          %Instance.Question{name: "amount", type: "text", inputType: "number"},
          %Instance.Question{
            name: "justification",
            type: "comment",
            isRequired: true,
            visibleIf: "{type} = 'expense' and {amount} > 100"
          }
        ]
      }

      visible_params = %{"type" => "expense", "amount" => "150"}
      changeset = Changeset.create_changeset(instance, visible_params)
      refute changeset.valid?
      assert changeset.errors[:justification]

      hidden_params = %{"type" => "expense", "amount" => "50"}
      changeset = Changeset.create_changeset(instance, hidden_params)
      assert changeset.valid?
    end
  end

  describe "create_changeset/2 - requiredIf" do
    test "field becomes required when requiredIf evaluates to true" do
      instance = %Instance{
        id: "required-if-form",
        elements: [
          %Instance.Question{name: "has_pet", type: "boolean"},
          %Instance.Question{
            name: "pet_name",
            type: "text",
            requiredIf: "{has_pet} = true"
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"has_pet" => "true"})
      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:pet_name]

      changeset = Changeset.create_changeset(instance, %{"has_pet" => "false"})
      assert changeset.valid?
    end

    test "requiredIf does not apply to hidden fields" do
      instance = %Instance{
        id: "required-if-hidden-form",
        elements: [
          %Instance.Question{name: "show", type: "boolean"},
          %Instance.Question{name: "trigger", type: "boolean"},
          %Instance.Question{
            name: "detail",
            type: "text",
            requiredIf: "{trigger} = true",
            visibleIf: "{show} = true"
          }
        ]
      }

      params = %{"show" => "false", "trigger" => "true"}
      changeset = Changeset.create_changeset(instance, params)
      assert changeset.valid?
    end
  end

  describe "create_changeset/2 - validators" do
    test "text validator enforces minLength and maxLength" do
      instance = %Instance{
        id: "text-validator-form",
        elements: [
          %Instance.Question{
            name: "username",
            type: "text",
            validators: [%Instance.Validator{type: "text", minLength: 3, maxLength: 10}]
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"username" => "ab"})
      refute changeset.valid?
      assert changeset.errors[:username]

      changeset = Changeset.create_changeset(instance, %{"username" => "abcdefghijk"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"username" => "abcdef"})
      assert changeset.valid?
    end

    test "numeric validator enforces minValue and maxValue" do
      instance = %Instance{
        id: "numeric-validator-form",
        elements: [
          %Instance.Question{
            name: "quantity",
            type: "text",
            inputType: "number",
            validators: [%Instance.Validator{type: "numeric", minValue: 1, maxValue: 10}]
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"quantity" => "0"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"quantity" => "11"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"quantity" => "5"})
      assert changeset.valid?
    end

    test "email validator enforces email format" do
      instance = %Instance{
        id: "email-validator-form",
        elements: [
          %Instance.Question{
            name: "email",
            type: "text",
            validators: [%Instance.Validator{type: "email"}]
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"email" => "invalid"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"email" => "user@example.com"})
      assert changeset.valid?
    end

    test "regex validator enforces pattern" do
      instance = %Instance{
        id: "regex-validator-form",
        elements: [
          %Instance.Question{
            name: "zip",
            type: "text",
            validators: [%Instance.Validator{type: "regex", regex: "^\\d{5}$"}]
          }
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"zip" => "abcde"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"zip" => "80202"})
      assert changeset.valid?
    end

    test "inputType email applies implicit format validation" do
      instance = %Instance{
        id: "input-type-email-form",
        elements: [
          %Instance.Question{name: "email", type: "text", inputType: "email"}
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"email" => "invalid"})
      refute changeset.valid?
    end

    test "validator text provides a custom error message" do
      instance = %Instance{
        id: "custom-message-form",
        elements: [
          %Instance.Question{
            name: "username",
            type: "text",
            validators: [
              %Instance.Validator{type: "text", minLength: 5, text: "Too short, friend"}
            ]
          },
          %Instance.Question{
            name: "email",
            type: "text",
            validators: [%Instance.Validator{type: "email", text: "Not a valid email"}]
          }
        ]
      }

      changeset =
        Changeset.create_changeset(instance, %{"username" => "abc", "email" => "nope"})

      assert {"Too short, friend", _} = changeset.errors[:username]
      assert {"Not a valid email", _} = changeset.errors[:email]
    end

    test "rating questions validate against rateMin/rateMax" do
      instance = %Instance{
        id: "rating-form",
        elements: [
          %Instance.Question{name: "score", type: "rating", rateMin: 1, rateMax: 10}
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"score" => "11"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"score" => "10"})
      assert changeset.valid?
    end

    test "rating questions default to a 1..5 range" do
      instance = %Instance{
        id: "rating-default-form",
        elements: [%Instance.Question{name: "score", type: "rating"}]
      }

      changeset = Changeset.create_changeset(instance, %{"score" => "6"})
      refute changeset.valid?

      changeset = Changeset.create_changeset(instance, %{"score" => "3"})
      assert changeset.valid?
    end
  end

  describe "create_changeset/2 - array params" do
    test "strips hidden-input empty strings from checkbox values" do
      instance = %Instance{
        id: "checkbox-form",
        elements: [%Instance.Question{name: "toppings", type: "checkbox"}]
      }

      changeset = Changeset.create_changeset(instance, %{"toppings" => ["", "cheese"]})
      assert Ecto.Changeset.get_change(changeset, :toppings) == ["cheese"]
    end

    test "an all-empty checkbox submission fails required validation" do
      instance = %Instance{
        id: "required-checkbox-form",
        elements: [
          %Instance.Question{name: "toppings", type: "checkbox", isRequired: true}
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"toppings" => [""]})
      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:toppings]
    end
  end

  # Browsers submit "" for every untouched text/number input. These pin that
  # empty strings are treated as empty values, not cast as real ones.
  describe "create_changeset/2 - empty string params" do
    test "empty strings fail required validation" do
      instance = %Instance{
        id: "blank-required-form",
        elements: [
          %Instance.Question{name: "name", type: "text", isRequired: true},
          %Instance.Question{name: "city", type: "text", isRequired: true}
        ]
      }

      changeset = Changeset.create_changeset(instance, %{"name" => "", "city" => ""})

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:name]
      assert {"can't be blank", _} = changeset.errors[:city]
    end

    test "an empty string on an optional number field is not a cast error" do
      instance = %Instance{
        id: "optional-number-form",
        elements: [
          %Instance.Question{name: "name", type: "text", isRequired: true},
          %Instance.Question{name: "age", type: "text", inputType: "number"}
        ]
      }

      changeset =
        Changeset.create_changeset(instance, %{"name" => "Chris", "age" => ""})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :age) == nil
    end

    test "an empty string on an optional rating field is not a cast error" do
      instance = %Instance{
        id: "optional-rating-form",
        elements: [%Instance.Question{name: "score", type: "rating"}]
      }

      changeset = Changeset.create_changeset(instance, %{"score" => ""})

      assert changeset.valid?
    end
  end

  describe "create_changeset/2 - file uploads" do
    test "decodes JSON-encoded file upload params" do
      instance = %Instance{
        id: "upload-form",
        elements: [%Instance.Question{name: "documents", type: "file"}]
      }

      files = [%{"filename" => "doc.pdf", "cloud_path" => "uploads/doc.pdf"}]
      params = %{"documents" => Jason.encode!(files)}

      changeset = Changeset.create_changeset(instance, params)
      assert Ecto.Changeset.get_change(changeset, :documents) == files
    end
  end

  describe "list_questions/1" do
    test "returns questions and recurses into panels, skipping other elements" do
      elements = [
        %Instance.Element{name: "intro", type: "html", html: "<p>Hi</p>"},
        %Instance.Question{name: "email", type: "text"},
        %Instance.Element{
          name: "panel",
          type: "panel",
          elements: [%Instance.Question{name: "city", type: "text"}]
        }
      ]

      assert [%Instance.Question{name: "email"}, %Instance.Question{name: "city"}] =
               Changeset.list_questions(elements)
    end
  end
end
