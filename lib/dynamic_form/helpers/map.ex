defmodule DynamicForm.Helpers.Map do
  @moduledoc """
  Generic map utilities shared across the library.

  Internal module — not part of the public API.
  """

  @doc """
  Converts the top-level keys of a map to strings, leaving values untouched.

  Structs are converted to plain maps first.
  """
  def stringify_keys(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> stringify_keys()
  end

  def stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  @doc """
  Recursively converts all map keys to strings, descending into nested maps
  and lists.

  `Decimal` values pass through untouched; any other struct is converted to a
  plain map (dropping `__struct__`) and descended into. Non-map, non-list
  values are returned as-is.
  """
  def deep_stringify_keys(%Decimal{} = value), do: value

  def deep_stringify_keys(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> deep_stringify_keys()
  end

  def deep_stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), deep_stringify_keys(value)} end)
  end

  def deep_stringify_keys(list) when is_list(list) do
    Enum.map(list, &deep_stringify_keys/1)
  end

  def deep_stringify_keys(value), do: value

  @doc """
  Puts `value` under `key` unless the value is `nil`.

  `false` and other falsy-looking values are still put — only `nil` is skipped.
  """
  def put_unless_nil(map, _key, nil), do: map
  def put_unless_nil(map, key, value), do: Map.put(map, key, value)
end
