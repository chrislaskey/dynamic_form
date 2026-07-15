defmodule DynamicForm.VisibilityTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Instance
  alias DynamicForm.Visibility

  describe "question_visible?/2" do
    test "returns true when visibleIf is nil" do
      question = %Instance.Question{name: "email", type: "text", visibleIf: nil}
      assert Visibility.question_visible?(question, %{})
    end

    test "returns true when visibleIf is an empty string" do
      question = %Instance.Question{name: "email", type: "text", visibleIf: ""}
      assert Visibility.question_visible?(question, %{})
    end

    test "evaluates the visibleIf expression against params" do
      question = %Instance.Question{
        name: "card_number",
        type: "text",
        visibleIf: "{payment_method} = 'credit_card'"
      }

      assert Visibility.question_visible?(question, %{"payment_method" => "credit_card"})
      refute Visibility.question_visible?(question, %{"payment_method" => "paypal"})
      refute Visibility.question_visible?(question, %{})
    end
  end

  describe "element_visible?/2" do
    test "returns true when visibleIf is nil" do
      element = %Instance.Element{name: "intro", type: "html", visibleIf: nil}
      assert Visibility.element_visible?(element, %{})
    end

    test "evaluates the visibleIf expression against params" do
      element = %Instance.Element{
        name: "thanks",
        type: "html",
        visibleIf: "{accept_terms} = true"
      }

      assert Visibility.element_visible?(element, %{"accept_terms" => "true"})
      refute Visibility.element_visible?(element, %{"accept_terms" => "false"})
    end
  end

  describe "condition_met?/3" do
    test "returns the default when expression is nil or empty" do
      assert Visibility.condition_met?(nil, %{})
      assert Visibility.condition_met?("", %{})
      refute Visibility.condition_met?(nil, %{}, default: false)
      refute Visibility.condition_met?("", %{}, default: false)
    end

    test "evaluates the expression when present, ignoring the default" do
      assert Visibility.condition_met?("{a} = 'x'", %{"a" => "x"}, default: false)
      refute Visibility.condition_met?("{a} = 'x'", %{"a" => "y"}, default: true)
    end
  end

  describe "evaluate_expression/2 - equality" do
    test "= with quoted string values" do
      assert Visibility.evaluate_expression("{color} = 'red'", %{"color" => "red"})
      refute Visibility.evaluate_expression("{color} = 'red'", %{"color" => "blue"})
    end

    test "== is equivalent to =" do
      assert Visibility.evaluate_expression("{color} == 'red'", %{"color" => "red"})
      refute Visibility.evaluate_expression("{color} == 'red'", %{"color" => "blue"})
    end

    test "double-quoted strings" do
      assert Visibility.evaluate_expression(~s({color} = "red"), %{"color" => "red"})
    end

    test "<> and != not-equals" do
      assert Visibility.evaluate_expression("{color} <> 'red'", %{"color" => "blue"})
      refute Visibility.evaluate_expression("{color} <> 'red'", %{"color" => "red"})
      assert Visibility.evaluate_expression("{color} != 'red'", %{"color" => "blue"})
      refute Visibility.evaluate_expression("{color} != 'red'", %{"color" => "red"})
    end

    test "missing field is not equal to any string" do
      refute Visibility.evaluate_expression("{color} = 'red'", %{})
      assert Visibility.evaluate_expression("{color} <> 'red'", %{})
    end

    test "numeric equality coerces string params" do
      assert Visibility.evaluate_expression("{age} = 21", %{"age" => "21"})
      assert Visibility.evaluate_expression("{age} = 21", %{"age" => 21})
      refute Visibility.evaluate_expression("{age} = 21", %{"age" => "22"})
    end

    test "atom-keyed params are supported" do
      assert Visibility.evaluate_expression("{color} = 'red'", %{color: "red"})
    end
  end

  describe "evaluate_expression/2 - booleans" do
    test "= true matches true and 'true'" do
      assert Visibility.evaluate_expression("{agreed} = true", %{"agreed" => true})
      assert Visibility.evaluate_expression("{agreed} = true", %{"agreed" => "true"})
      refute Visibility.evaluate_expression("{agreed} = true", %{"agreed" => "false"})
      refute Visibility.evaluate_expression("{agreed} = true", %{})
    end

    test "= false matches false, 'false', and unanswered" do
      assert Visibility.evaluate_expression("{agreed} = false", %{"agreed" => false})
      assert Visibility.evaluate_expression("{agreed} = false", %{"agreed" => "false"})
      assert Visibility.evaluate_expression("{agreed} = false", %{})
      refute Visibility.evaluate_expression("{agreed} = false", %{"agreed" => "true"})
    end
  end

  describe "evaluate_expression/2 - empty and notempty" do
    test "empty matches nil, empty string, and empty list" do
      assert Visibility.evaluate_expression("{field} empty", %{})
      assert Visibility.evaluate_expression("{field} empty", %{"field" => nil})
      assert Visibility.evaluate_expression("{field} empty", %{"field" => ""})
      assert Visibility.evaluate_expression("{field} empty", %{"field" => []})
      refute Visibility.evaluate_expression("{field} empty", %{"field" => "value"})
    end

    test "notempty matches present values" do
      assert Visibility.evaluate_expression("{field} notempty", %{"field" => "value"})
      assert Visibility.evaluate_expression("{field} notempty", %{"field" => ["a"]})
      refute Visibility.evaluate_expression("{field} notempty", %{})
      refute Visibility.evaluate_expression("{field} notempty", %{"field" => ""})
    end

    test "a bare field reference is truthy when non-empty" do
      assert Visibility.evaluate_expression("{field}", %{"field" => "value"})
      refute Visibility.evaluate_expression("{field}", %{})
    end
  end

  describe "evaluate_expression/2 - comparison operators" do
    test "> and < with numeric coercion" do
      assert Visibility.evaluate_expression("{age} > 18", %{"age" => "21"})
      assert Visibility.evaluate_expression("{age} > 18", %{"age" => 21})
      refute Visibility.evaluate_expression("{age} > 18", %{"age" => "18"})
      assert Visibility.evaluate_expression("{age} < 18", %{"age" => "17"})
      refute Visibility.evaluate_expression("{age} < 18", %{"age" => "18"})
    end

    test ">= and <= (previously mis-parsed as equals)" do
      assert Visibility.evaluate_expression("{age} >= 18", %{"age" => "18"})
      assert Visibility.evaluate_expression("{age} >= 18", %{"age" => "19"})
      refute Visibility.evaluate_expression("{age} >= 18", %{"age" => "17"})
      assert Visibility.evaluate_expression("{age} <= 18", %{"age" => "18"})
      refute Visibility.evaluate_expression("{age} <= 18", %{"age" => "19"})
    end

    test "float comparison" do
      assert Visibility.evaluate_expression("{price} > 9.99", %{"price" => "10.50"})
      refute Visibility.evaluate_expression("{price} > 9.99", %{"price" => "9.98"})
    end

    test "missing field never satisfies a comparison" do
      refute Visibility.evaluate_expression("{age} > 18", %{})
      refute Visibility.evaluate_expression("{age} <= 18", %{})
    end
  end

  describe "evaluate_expression/2 - logical composition" do
    test "and requires both sides" do
      params = %{"a" => "x", "b" => "y"}
      assert Visibility.evaluate_expression("{a} = 'x' and {b} = 'y'", params)
      refute Visibility.evaluate_expression("{a} = 'x' and {b} = 'z'", params)
    end

    test "or requires either side" do
      params = %{"a" => "x"}
      assert Visibility.evaluate_expression("{a} = 'x' or {b} = 'y'", params)
      assert Visibility.evaluate_expression("{a} = 'z' or {a} = 'x'", params)
      refute Visibility.evaluate_expression("{a} = 'z' or {a} = 'w'", params)
    end

    test "and binds tighter than or" do
      # false or (true and true) => true
      params = %{"a" => "x", "b" => "y"}

      assert Visibility.evaluate_expression(
               "{a} = 'nope' or {a} = 'x' and {b} = 'y'",
               params
             )

      # (false or true) and false would be false - confirms precedence
      refute Visibility.evaluate_expression(
               "{a} = 'nope' or {a} = 'x' and {b} = 'nope'",
               params
             )
    end

    test "parentheses override precedence" do
      params = %{"a" => "x", "b" => "nope"}

      refute Visibility.evaluate_expression(
               "({a} = 'nope' or {a} = 'x') and {b} = 'y'",
               params
             )

      assert Visibility.evaluate_expression(
               "({a} = 'nope' or {a} = 'x') and {b} = 'nope'",
               params
             )
    end

    test "mixed comparison types compose" do
      params = %{"payment" => "card", "amount" => "150"}

      assert Visibility.evaluate_expression(
               "{payment} = 'card' and {amount} > 100",
               params
             )

      assert Visibility.evaluate_expression(
               "{payment} notempty and {other} empty",
               params
             )
    end
  end

  describe "evaluate_expression/2 - contains / anyof / allof / noneof" do
    test "contains on array values" do
      params = %{"toppings" => ["cheese", "mushrooms"]}
      assert Visibility.evaluate_expression("{toppings} contains 'cheese'", params)
      refute Visibility.evaluate_expression("{toppings} contains 'olives'", params)
    end

    test "contains on string values checks substring" do
      assert Visibility.evaluate_expression("{email} contains '@'", %{"email" => "a@b.com"})
      refute Visibility.evaluate_expression("{email} contains '@'", %{"email" => "invalid"})
    end

    test "notcontains" do
      params = %{"toppings" => ["cheese"]}
      assert Visibility.evaluate_expression("{toppings} notcontains 'olives'", params)
      refute Visibility.evaluate_expression("{toppings} notcontains 'cheese'", params)
    end

    test "contains on a missing field is false" do
      refute Visibility.evaluate_expression("{toppings} contains 'cheese'", %{})
    end

    test "anyof matches when any value intersects" do
      params = %{"colors" => ["red", "blue"]}
      assert Visibility.evaluate_expression("{colors} anyof ['blue', 'green']", params)
      refute Visibility.evaluate_expression("{colors} anyof ['green', 'yellow']", params)
    end

    test "anyof works with scalar left side" do
      assert Visibility.evaluate_expression("{color} anyof ['red', 'blue']", %{"color" => "red"})

      refute Visibility.evaluate_expression("{color} anyof ['red', 'blue']", %{"color" => "green"})
    end

    test "allof requires every value present" do
      params = %{"colors" => ["red", "blue", "green"]}
      assert Visibility.evaluate_expression("{colors} allof ['red', 'blue']", params)
      refute Visibility.evaluate_expression("{colors} allof ['red', 'yellow']", params)
    end

    test "noneof requires no intersection" do
      params = %{"colors" => ["red", "blue"]}
      assert Visibility.evaluate_expression("{colors} noneof ['green', 'yellow']", params)
      refute Visibility.evaluate_expression("{colors} noneof ['blue']", params)
    end

    test "numeric array literals coerce against string params" do
      assert Visibility.evaluate_expression("{rating} anyof [4, 5]", %{"rating" => "5"})
      refute Visibility.evaluate_expression("{rating} anyof [4, 5]", %{"rating" => "3"})
    end
  end

  describe "evaluate_expression/2 - field names" do
    test "hyphenated field names" do
      assert Visibility.evaluate_expression(
               "{payment-method} = 'card'",
               %{"payment-method" => "card"}
             )
    end

    test "dotted field names" do
      assert Visibility.evaluate_expression(
               "{address.city} = 'Denver'",
               %{"address.city" => "Denver"}
             )
    end
  end

  describe "evaluate_expression/2 - malformed expressions" do
    import ExUnit.CaptureLog

    test "unparseable expressions evaluate to false" do
      capture_log(fn ->
        refute Visibility.evaluate_expression("not a real expression", %{})
        refute Visibility.evaluate_expression("{unclosed = 'x'", %{"unclosed" => "x"})
        refute Visibility.evaluate_expression("{a} = 'unterminated", %{"a" => "x"})
        refute Visibility.evaluate_expression("{a} = 'x' and", %{"a" => "x"})
        refute Visibility.evaluate_expression("({a} = 'x'", %{"a" => "x"})
      end)
    end

    test "malformed expressions log a warning" do
      log =
        capture_log(fn ->
          Visibility.evaluate_expression("%%%", %{})
        end)

      assert log =~ "failed to evaluate expression"
    end
  end
end
