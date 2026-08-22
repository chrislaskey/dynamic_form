defmodule DynamicForm.Visibility do
  @moduledoc false
  # Internal module for evaluating SurveyJS conditional expressions
  # (`visibleIf`, `requiredIf`, `enableIf`) against form parameter values.
  #
  # ## SurveyJS Expression Syntax
  #
  # Supported grammar (see https://surveyjs.io/form-library/documentation/design-survey/conditional-logic):
  #
  #   * Comparison: `{field} = 'value'`, `==`, `<>`, `!=`, `>`, `<`, `>=`, `<=`
  #   * Emptiness: `{field} empty`, `{field} notempty`
  #   * Array/string: `{field} contains 'x'`, `notcontains`, `anyof [..]`,
  #     `allof [..]`, `noneof [..]`
  #   * Logical composition: `and`, `or`, parentheses
  #   * Literals: single/double-quoted strings, numbers, `true`/`false`,
  #     arrays `[1, 'a', ...]`
  #
  # Unparseable expressions evaluate to `false` (question hidden / not
  # required / disabled), matching the previous fail-safe behavior.

  require Logger

  alias DynamicForm.Instance

  @doc """
  Determines if a question is visible based on its visibleIf expression and current params.

  ## Parameters

    * `question` - An `Instance.Question` struct
    * `params` - Map of current form values (string or atom keys)

  ## Returns

    * `true` - Question is visible (no conditions or conditions evaluate to true)
    * `false` - Question is hidden (conditions evaluate to false)

  ## Examples

      # Question with no visibleIf - always visible
      question = %Instance.Question{name: "email", visibleIf: nil}
      Visibility.question_visible?(question, %{}) #=> true

      # Question with equals expression
      question = %Instance.Question{
        name: "card_number",
        visibleIf: "{payment_method} = 'credit_card'"
      }
      Visibility.question_visible?(question, %{"payment_method" => "credit_card"}) #=> true
      Visibility.question_visible?(question, %{"payment_method" => "paypal"}) #=> false
  """
  def question_visible?(%Instance.Question{visibleIf: expression}, params) do
    condition_met?(expression, params, default: true)
  end

  @doc """
  Determines if an element is visible based on its visibleIf expression and current params.
  """
  def element_visible?(%Instance.Element{visibleIf: expression}, params) do
    condition_met?(expression, params, default: true)
  end

  @doc """
  Filters elements (questions and containers) to those whose `visibleIf`
  expression is met by the given params.
  """
  def visible_elements(elements, params) do
    Enum.filter(elements, fn
      %Instance.Question{} = question -> question_visible?(question, params)
      %Instance.Element{} = element -> element_visible?(element, params)
    end)
  end

  @doc """
  Evaluates an optional condition expression, returning a default when absent.

  Used for `visibleIf` (default: visible), `requiredIf` (default: not
  conditionally required), and `enableIf` (default: enabled).
  """
  def condition_met?(expression, params, opts \\ [])

  def condition_met?(nil, _params, opts), do: Keyword.get(opts, :default, true)
  def condition_met?("", _params, opts), do: Keyword.get(opts, :default, true)

  def condition_met?(expression, params, _opts) when is_binary(expression) do
    evaluate_expression(expression, params)
  end

  @doc """
  Evaluates a SurveyJS conditional expression against the current params.

  ## Supported Expressions

    * `{field} = 'value'` / `==` - Equals
    * `{field} <> 'value'` / `!=` - Not equals
    * `{field} > 5`, `<`, `>=`, `<=` - Numeric/string comparison
    * `{field} empty` / `{field} notempty` - Emptiness checks
    * `{field} contains 'x'` / `notcontains` - Array membership or substring
    * `{field} anyof ['a', 'b']` / `allof` / `noneof` - Array operators
    * `expr and expr`, `expr or expr`, parentheses - Logical composition

  ## Returns

    * `true` - Expression evaluates to true
    * `false` - Expression evaluates to false or parsing fails
  """
  def evaluate_expression(expression, params) when is_binary(expression) do
    with {:ok, tokens} <- tokenize(expression),
         {:ok, ast} <- parse(tokens) do
      evaluate(ast, params)
    else
      {:error, reason} ->
        Logger.warning(
          "DynamicForm: failed to evaluate expression #{inspect(expression)}: #{reason}"
        )

        false
    end
  end

  # ---------------------------------------------------------------------------
  # Tokenizer
  # ---------------------------------------------------------------------------

  defp tokenize(expression) do
    do_tokenize(expression, [])
  end

  defp do_tokenize("", acc), do: {:ok, Enum.reverse(acc)}

  defp do_tokenize(<<c::utf8, rest::binary>>, acc) when c in [?\s, ?\t, ?\n, ?\r] do
    do_tokenize(rest, acc)
  end

  defp do_tokenize("{" <> rest, acc) do
    case String.split(rest, "}", parts: 2) do
      [name, rest] when name != "" -> do_tokenize(rest, [{:field, String.trim(name)} | acc])
      _ -> {:error, "unterminated field reference"}
    end
  end

  defp do_tokenize("'" <> rest, acc), do: tokenize_string(rest, "'", acc)
  defp do_tokenize("\"" <> rest, acc), do: tokenize_string(rest, "\"", acc)

  defp do_tokenize("(" <> rest, acc), do: do_tokenize(rest, [:lparen | acc])
  defp do_tokenize(")" <> rest, acc), do: do_tokenize(rest, [:rparen | acc])
  defp do_tokenize("[" <> rest, acc), do: do_tokenize(rest, [:lbracket | acc])
  defp do_tokenize("]" <> rest, acc), do: do_tokenize(rest, [:rbracket | acc])
  defp do_tokenize("," <> rest, acc), do: do_tokenize(rest, [:comma | acc])

  defp do_tokenize("<=" <> rest, acc), do: do_tokenize(rest, [{:op, :le} | acc])
  defp do_tokenize(">=" <> rest, acc), do: do_tokenize(rest, [{:op, :ge} | acc])
  defp do_tokenize("<>" <> rest, acc), do: do_tokenize(rest, [{:op, :ne} | acc])
  defp do_tokenize("!=" <> rest, acc), do: do_tokenize(rest, [{:op, :ne} | acc])
  defp do_tokenize("==" <> rest, acc), do: do_tokenize(rest, [{:op, :eq} | acc])
  defp do_tokenize("=" <> rest, acc), do: do_tokenize(rest, [{:op, :eq} | acc])
  defp do_tokenize("<" <> rest, acc), do: do_tokenize(rest, [{:op, :lt} | acc])
  defp do_tokenize(">" <> rest, acc), do: do_tokenize(rest, [{:op, :gt} | acc])

  defp do_tokenize(binary, acc) do
    case Regex.run(~r/^[\w.-]+/, binary) do
      [word] ->
        rest = binary_part(binary, byte_size(word), byte_size(binary) - byte_size(word))
        do_tokenize(rest, [word_token(word) | acc])

      nil ->
        {:error, "unexpected character at #{inspect(String.slice(binary, 0, 10))}"}
    end
  end

  defp tokenize_string(binary, quote_char, acc) do
    case String.split(binary, quote_char, parts: 2) do
      [value, rest] -> do_tokenize(rest, [{:string, value} | acc])
      _ -> {:error, "unterminated string literal"}
    end
  end

  @keyword_tokens %{
    "and" => :and,
    "or" => :or,
    "true" => {:boolean, true},
    "false" => {:boolean, false},
    "empty" => {:op, :empty},
    "notempty" => {:op, :notempty},
    "contains" => {:op, :contains},
    "contain" => {:op, :contains},
    "notcontains" => {:op, :notcontains},
    "notcontain" => {:op, :notcontains},
    "anyof" => {:op, :anyof},
    "allof" => {:op, :allof},
    "noneof" => {:op, :noneof}
  }

  defp word_token(word) do
    case Map.fetch(@keyword_tokens, String.downcase(word)) do
      {:ok, token} -> token
      :error -> number_or_error(word)
    end
  end

  defp number_or_error(word) do
    case Integer.parse(word) do
      {int, ""} ->
        {:number, int}

      _ ->
        case Float.parse(word) do
          {float, ""} -> {:number, float}
          _ -> {:error, "unrecognized token #{inspect(word)}"}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Parser (recursive descent): or_expr > and_expr > comparison
  # ---------------------------------------------------------------------------

  defp parse(tokens) do
    if Enum.any?(tokens, &match?({:error, _}, &1)) do
      {:error, elem(Enum.find(tokens, &match?({:error, _}, &1)), 1)}
    else
      case parse_or(tokens) do
        {:ok, ast, []} -> {:ok, ast}
        {:ok, _ast, rest} -> {:error, "unexpected trailing tokens #{inspect(rest)}"}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_or(tokens) do
    with {:ok, left, rest} <- parse_and(tokens) do
      parse_or_rest(left, rest)
    end
  end

  defp parse_or_rest(left, [:or | rest]) do
    with {:ok, right, rest} <- parse_and(rest) do
      parse_or_rest({:or, left, right}, rest)
    end
  end

  defp parse_or_rest(left, rest), do: {:ok, left, rest}

  defp parse_and(tokens) do
    with {:ok, left, rest} <- parse_primary(tokens) do
      parse_and_rest(left, rest)
    end
  end

  defp parse_and_rest(left, [:and | rest]) do
    with {:ok, right, rest} <- parse_primary(rest) do
      parse_and_rest({:and, left, right}, rest)
    end
  end

  defp parse_and_rest(left, rest), do: {:ok, left, rest}

  defp parse_primary([:lparen | rest]) do
    with {:ok, inner, rest} <- parse_or(rest) do
      case rest do
        [:rparen | rest] -> {:ok, inner, rest}
        _ -> {:error, "expected closing parenthesis"}
      end
    end
  end

  defp parse_primary(tokens), do: parse_comparison(tokens)

  defp parse_comparison(tokens) do
    with {:ok, left, rest} <- parse_operand(tokens) do
      case rest do
        [{:op, op} | rest] when op in [:empty, :notempty] ->
          {:ok, {op, left}, rest}

        [{:op, op} | rest] ->
          with {:ok, right, rest} <- parse_operand(rest) do
            {:ok, {op, left, right}, rest}
          end

        _ ->
          # A bare operand (e.g. `{field}`) is truthy when non-empty
          {:ok, {:notempty, left}, rest}
      end
    end
  end

  defp parse_operand([{:field, name} | rest]), do: {:ok, {:field, name}, rest}
  defp parse_operand([{:string, value} | rest]), do: {:ok, {:literal, value}, rest}
  defp parse_operand([{:number, value} | rest]), do: {:ok, {:literal, value}, rest}
  defp parse_operand([{:boolean, value} | rest]), do: {:ok, {:literal, value}, rest}
  defp parse_operand([:lbracket | rest]), do: parse_array(rest, [])

  defp parse_operand(tokens),
    do: {:error, "expected operand, got #{inspect(Enum.take(tokens, 3))}"}

  defp parse_array([:rbracket | rest], acc), do: {:ok, {:literal, Enum.reverse(acc)}, rest}

  defp parse_array(tokens, acc) do
    case tokens do
      [{:string, value} | rest] -> parse_array_rest(rest, [value | acc])
      [{:number, value} | rest] -> parse_array_rest(rest, [value | acc])
      [{:boolean, value} | rest] -> parse_array_rest(rest, [value | acc])
      _ -> {:error, "expected array element"}
    end
  end

  defp parse_array_rest([:comma | rest], acc), do: parse_array(rest, acc)
  defp parse_array_rest([:rbracket | rest], acc), do: {:ok, {:literal, Enum.reverse(acc)}, rest}
  defp parse_array_rest(_tokens, _acc), do: {:error, "expected comma or closing bracket in array"}

  # ---------------------------------------------------------------------------
  # Evaluator
  # ---------------------------------------------------------------------------

  defp evaluate({:or, left, right}, params),
    do: evaluate(left, params) or evaluate(right, params)

  defp evaluate({:and, left, right}, params),
    do: evaluate(left, params) and evaluate(right, params)

  defp evaluate({:empty, operand}, params), do: not has_value?(resolve(operand, params))
  defp evaluate({:notempty, operand}, params), do: has_value?(resolve(operand, params))

  defp evaluate({:eq, left, right}, params),
    do: loose_equals?(resolve(left, params), resolve(right, params))

  defp evaluate({:ne, left, right}, params),
    do: not loose_equals?(resolve(left, params), resolve(right, params))

  defp evaluate({op, left, right}, params) when op in [:gt, :lt, :ge, :le] do
    compare(op, resolve(left, params), resolve(right, params))
  end

  defp evaluate({:contains, left, right}, params),
    do: contains?(resolve(left, params), resolve(right, params))

  defp evaluate({:notcontains, left, right}, params),
    do: not contains?(resolve(left, params), resolve(right, params))

  defp evaluate({:anyof, left, right}, params) do
    left = resolve(left, params) |> List.wrap()
    right = resolve(right, params) |> List.wrap()
    Enum.any?(left, fn item -> Enum.any?(right, &loose_equals?(item, &1)) end)
  end

  defp evaluate({:allof, left, right}, params) do
    left = resolve(left, params) |> List.wrap()
    right = resolve(right, params) |> List.wrap()
    Enum.all?(right, fn item -> Enum.any?(left, &loose_equals?(item, &1)) end)
  end

  defp evaluate({:noneof, left, right}, params) do
    left = resolve(left, params) |> List.wrap()
    right = resolve(right, params) |> List.wrap()
    not Enum.any?(left, fn item -> Enum.any?(right, &loose_equals?(item, &1)) end)
  end

  defp resolve({:field, name}, params), do: get_field_value(params, name)
  defp resolve({:literal, value}, _params), do: value

  # Loose equality with SurveyJS-style coercion: form params arrive as strings,
  # so "5" = 5, "true" = true, and unanswered booleans equal false.
  defp loose_equals?(value, value), do: true
  defp loose_equals?(nil, false), do: true
  defp loose_equals?(false, nil), do: true
  defp loose_equals?(value, true) when is_binary(value), do: value == "true"
  defp loose_equals?(true, value) when is_binary(value), do: value == "true"
  defp loose_equals?(value, false) when is_binary(value), do: value == "false"
  defp loose_equals?(false, value) when is_binary(value), do: value == "false"

  defp loose_equals?(left, right) when is_number(left) or is_number(right) do
    case {to_number(left), to_number(right)} do
      {nil, _} -> false
      {_, nil} -> false
      {left_num, right_num} -> left_num == right_num
    end
  end

  defp loose_equals?(_left, _right), do: false

  defp compare(_op, nil, _right), do: false
  defp compare(_op, _left, nil), do: false

  defp compare(op, left, right) do
    case {to_number(left), to_number(right)} do
      {left_num, right_num} when is_number(left_num) and is_number(right_num) ->
        do_compare(op, left_num, right_num)

      _ when is_binary(left) and is_binary(right) ->
        do_compare(op, left, right)

      _ ->
        false
    end
  end

  defp do_compare(:gt, left, right), do: left > right
  defp do_compare(:lt, left, right), do: left < right
  defp do_compare(:ge, left, right), do: left >= right
  defp do_compare(:le, left, right), do: left <= right

  defp contains?(nil, _item), do: false

  defp contains?(list, item) when is_list(list),
    do: Enum.any?(list, &loose_equals?(&1, item))

  defp contains?(string, item) when is_binary(string) and is_binary(item),
    do: String.contains?(string, item)

  defp contains?(_value, _item), do: false

  defp to_number(value) when is_number(value), do: value

  defp to_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} ->
        int

      _ ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> nil
        end
    end
  end

  defp to_number(_value), do: nil

  # Helper to get field value from params, handling both string and atom keys.
  # Inside a paneldynamic template, SurveyJS scopes sibling references as
  # `{panel.field}`; panel entries are validated/rendered against panel-local
  # params, so the prefix resolves to a plain local lookup.
  defp get_field_value(params, "panel." <> field_name = full_name) do
    case Map.get(params, full_name) do
      nil -> get_field_value(params, field_name)
      value -> value
    end
  end

  defp get_field_value(params, field_name) when is_binary(field_name) do
    Map.get(params, field_name) || Map.get(params, String.to_existing_atom(field_name))
  rescue
    ArgumentError -> Map.get(params, field_name)
  end

  # Helper to check if a value is considered "present"
  defp has_value?(nil), do: false
  defp has_value?(""), do: false
  defp has_value?([]), do: false
  defp has_value?(_), do: true
end
