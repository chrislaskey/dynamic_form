defmodule DynamicForm.Helpers.MapTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Helpers

  defmodule TestStruct do
    defstruct [:name, :nested, active: false]
  end

  describe "stringify_keys/1" do
    test "converts atom keys to strings" do
      assert Helpers.Map.stringify_keys(%{name: "Ada", age: 36}) ==
               %{"name" => "Ada", "age" => 36}
    end

    test "leaves string keys unchanged" do
      assert Helpers.Map.stringify_keys(%{"name" => "Ada"}) == %{"name" => "Ada"}
    end

    test "handles mixed atom and string keys" do
      assert Helpers.Map.stringify_keys(%{:name => "Ada", "age" => 36}) ==
               %{"name" => "Ada", "age" => 36}
    end

    test "converts integer keys to strings" do
      assert Helpers.Map.stringify_keys(%{1 => "one"}) == %{"1" => "one"}
    end

    test "is shallow: nested map values are untouched" do
      assert Helpers.Map.stringify_keys(%{outer: %{inner: 1}}) ==
               %{"outer" => %{inner: 1}}
    end

    test "is shallow: lists of maps are untouched" do
      assert Helpers.Map.stringify_keys(%{items: [%{a: 1}]}) ==
               %{"items" => [%{a: 1}]}
    end

    test "converts a struct to a plain map with string keys" do
      result = Helpers.Map.stringify_keys(%TestStruct{name: "Ada", nested: %{a: 1}})

      assert result == %{"name" => "Ada", "nested" => %{a: 1}, "active" => false}
      refute Map.has_key?(result, "__struct__")
    end

    test "handles an empty map" do
      assert Helpers.Map.stringify_keys(%{}) == %{}
    end
  end

  describe "deep_stringify_keys/1" do
    test "converts nested map keys at every level" do
      assert Helpers.Map.deep_stringify_keys(%{a: %{b: %{c: 1}}}) ==
               %{"a" => %{"b" => %{"c" => 1}}}
    end

    test "descends into lists of maps" do
      assert Helpers.Map.deep_stringify_keys(%{items: [%{a: 1}, %{b: 2}]}) ==
               %{"items" => [%{"a" => 1}, %{"b" => 2}]}
    end

    test "descends into bare lists" do
      assert Helpers.Map.deep_stringify_keys([%{a: 1}, "x", 2]) ==
               [%{"a" => 1}, "x", 2]
    end

    test "passes Decimal values through untouched" do
      decimal = Decimal.new("1.5")

      assert Helpers.Map.deep_stringify_keys(decimal) == decimal
      assert Helpers.Map.deep_stringify_keys(%{amount: decimal}) == %{"amount" => decimal}
    end

    test "converts other structs to plain maps and descends into them" do
      result = Helpers.Map.deep_stringify_keys(%TestStruct{name: "Ada", nested: %{a: 1}})

      assert result == %{"name" => "Ada", "nested" => %{"a" => 1}, "active" => false}
      refute Map.has_key?(result, "__struct__")
    end

    test "converts structs found inside nested values" do
      result = Helpers.Map.deep_stringify_keys(%{entry: %TestStruct{name: "Ada"}})

      assert result == %{
               "entry" => %{"name" => "Ada", "nested" => nil, "active" => false}
             }
    end

    test "returns scalars unchanged" do
      assert Helpers.Map.deep_stringify_keys("text") == "text"
      assert Helpers.Map.deep_stringify_keys(42) == 42
      assert Helpers.Map.deep_stringify_keys(nil) == nil
      assert Helpers.Map.deep_stringify_keys(true) == true
    end

    test "handles mixed atom and string keys" do
      assert Helpers.Map.deep_stringify_keys(%{:a => 1, "b" => %{c: 2}}) ==
               %{"a" => 1, "b" => %{"c" => 2}}
    end

    test "handles an empty map" do
      assert Helpers.Map.deep_stringify_keys(%{}) == %{}
    end
  end

  describe "put_unless_nil/3" do
    test "skips nil values" do
      assert Helpers.Map.put_unless_nil(%{a: 1}, :b, nil) == %{a: 1}
    end

    test "puts false" do
      assert Helpers.Map.put_unless_nil(%{}, :flag, false) == %{flag: false}
    end

    test "puts empty string and zero" do
      assert Helpers.Map.put_unless_nil(%{}, :text, "") == %{text: ""}
      assert Helpers.Map.put_unless_nil(%{}, :count, 0) == %{count: 0}
    end

    test "puts regular values" do
      assert Helpers.Map.put_unless_nil(%{}, :name, "Ada") == %{name: "Ada"}
    end

    test "overwrites an existing key" do
      assert Helpers.Map.put_unless_nil(%{name: "Ada"}, :name, "Grace") == %{name: "Grace"}
    end

    test "does not overwrite an existing key with nil" do
      assert Helpers.Map.put_unless_nil(%{name: "Ada"}, :name, nil) == %{name: "Ada"}
    end
  end
end
