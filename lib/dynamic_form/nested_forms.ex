defmodule DynamicForm.NestedForms do
  @moduledoc """
  Nested/repeating child forms — the SurveyJS `paneldynamic` question type.

  A paneldynamic question holds a repeating template (`templateElements`);
  its value is a list of entries, one map per repetition. This module owns
  the entry machinery shared by validation and rendering:

    * `entries/1` — normalize a raw value into an ordered entry list
    * `entry_changesets/3` — build one child changeset per entry
    * `new_entry/1` — seed params for a newly added entry
    * `validate/3` — validate a parent changeset's paneldynamic questions

  Entry changesets are ordinary schemaless changesets built recursively via
  `DynamicForm.Changeset.create_changeset/3` — there is no Ecto relation
  (no `cast_embed`/`inputs_for`) involved. Because entries aren't tracked
  inside the parent changeset, they are *derived state*: a pure function of
  the question and the parent's raw params. Validation and rendering both
  call `entry_changesets/3`, so the errors they see are always identical.

  SurveyJS vocabulary ("panel") appears only at the boundary — the question
  type string, the `Instance.Question` fields, and `{panel.field}`
  expression scoping. Internally these are entries of a nested form.
  """

  alias DynamicForm.{Changeset, Instance}
  alias DynamicForm.Instance.Elements

  @id_field "dynamic_form_id"

  @doc """
  The entry field carrying a stable id, when `generateIds` is on.

  Entries are otherwise positional, so a value referencing one (a checkbox
  listing another nested form's entries, say) has nothing durable to point
  at: a member field changes when the user edits it, and an index changes
  when entries are added or removed. This field is seeded once — copied from
  the entry's `id` when the data came from a stored record, generated
  otherwise — and round-trips through a hidden input.

  It is only stable across sessions if the application persists it and
  passes it back in `data`.
  """
  def id_field, do: @id_field

  @doc """
  Whether a paneldynamic question seeds entry ids. On unless `generateIds`
  is explicitly `false`.
  """
  def generate_ids?(%Instance.Question{generateIds: false}), do: false
  def generate_ids?(%Instance.Question{}), do: true

  @doc """
  Builds one child changeset per entry of a paneldynamic question.

  Each entry of the question's value is validated against the question's
  `templateElements` with the same rules as a top-level form (casting,
  required fields, validators, conditional expressions), recursively — so
  nested paneldynamic questions work too. Conditional expressions inside the
  template can reference sibling values as `{panel.field}` (or plain
  `{field}`), and form-level values by their names.

  When the question defines `keyName`, entries duplicating another entry's
  value for that field get an error (message: `keyDuplicationError`).

  Both validation (`DynamicForm.Changeset.create_changeset/3`) and rendering
  (`DynamicForm.Renderer`) call this with the parent's raw params, so the
  changesets — and their errors — are identical in both places.

  `parent_params` is the parent changeset's params map; the entry list is
  read from it under the question's name (either a list or a
  `%{"0" => ...}`-indexed map as submitted by the browser).
  """
  def entry_changesets(
        %Instance.Question{type: "paneldynamic"} = question,
        parent_params,
        opts \\ []
      ) do
    template = %Instance{
      id: "#{question.name}-template",
      elements: template_elements(question)
    }

    children =
      parent_params
      |> Map.get(question.name)
      |> entries()
      |> Enum.map(fn entry ->
        entry = if is_map(entry), do: entry, else: %{}

        # Entry-local values win over form-level values with the same name;
        # `panel.`-prefixed copies make `{panel.field}` references resolve.
        context =
          parent_params
          |> Map.merge(entry)
          |> Map.merge(panel_prefixed(entry))

        Changeset.create_changeset(
          template,
          entry,
          Keyword.put(opts, :visibility_params, context)
        )
      end)

    apply_key_duplication(children, question)
  end

  @doc """
  Normalizes a paneldynamic value to a list of entries.

  Browser submissions arrive as an indexed map (`%{"0" => %{...}, "1" =>
  %{...}}`, possibly with non-integer bookkeeping keys such as the always-
  present `__empty__` hidden input); programmatic values are already lists.
  """
  def entries(value) do
    case value do
      list when is_list(list) ->
        list

      %{} = indexed ->
        indexed
        |> Enum.filter(fn {key, _} -> match?({_, ""}, Integer.parse(key)) end)
        |> Enum.sort_by(fn {key, _} -> String.to_integer(key) end)
        |> Enum.map(fn {_, entry} -> entry end)

      _ ->
        []
    end
  end

  @doc """
  The initial params for a newly added entry.

  Template questions' `defaultValue`s seed the entry, overridden by the
  question's `defaultPanelValue`. The entry's `dynamic_form_id` is seeded
  separately by `seed_entry_ids/2`, which runs over the changeset's params —
  generating one here would leak into `initial_data` and reset the form on
  every parent re-render.
  """
  def new_entry(%Instance.Question{type: "paneldynamic"} = question) do
    defaults =
      (question.templateElements || [])
      |> Elements.list_questions()
      |> Enum.reduce(%{}, fn template_question, acc ->
        case template_question.defaultValue do
          nil -> acc
          default -> Map.put(acc, template_question.name, default)
        end
      end)

    default_entry = Map.new(question.defaultPanelValue || %{}, fn {k, v} -> {to_string(k), v} end)

    Map.merge(defaults, default_entry)
  end

  @doc """
  Seeds paneldynamic questions without initial data with `panelCount` fresh
  entries (at least `minPanelCount`), mirroring SurveyJS. Every entry is
  seeded separately so each gets its own id.
  """
  def seed_entries(params, questions) when is_map(params) do
    questions
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(params, fn question, acc ->
      count = max(question.panelCount || 0, question.minPanelCount || 0)
      new_entries = Enum.map(1..count//1, fn _ -> new_entry(question) end)
      Map.put_new(acc, question.name, new_entries)
    end)
  end

  @doc """
  Walks the params tree along an entry path and updates the entry list at
  its end with `fun`. Path segments alternate between map keys (question
  names) and list indexes (entries).
  """
  def update_entry_list(params, [name], fun) when is_map(params) do
    current_entries = params |> Map.get(name) |> entries()
    Map.put(params, name, fun.(current_entries))
  end

  def update_entry_list(params, [name | rest], fun) when is_map(params) do
    Map.put(params, name, update_entry_list(Map.get(params, name) || %{}, rest, fun))
  end

  def update_entry_list(current_entries, [index | rest], fun) when is_list(current_entries) do
    List.update_at(current_entries, String.to_integer(index), &update_entry_list(&1, rest, fun))
  end

  @doc """
  Seeds `dynamic_form_id` on every entry of the given questions' values.

  Runs over string-keyed params when a form is built or reset, recursing
  into nested templates. An entry that already carries an id keeps it; one
  carrying an `id` from a stored record adopts that; anything else — an
  entry the user created this session — gets a generated one.

  Generation happens here rather than at render time on purpose: a fresh id
  per render would be worse than no id at all.
  """
  def seed_entry_ids(params, questions) when is_map(params) do
    questions
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(params, fn question, acc ->
      case Map.get(acc, question.name) do
        nil ->
          acc

        value ->
          Map.put(acc, question.name, Enum.map(entries(value), &seed_entry(&1, question)))
      end
    end)
  end

  def seed_entry_ids(params, _questions), do: params

  defp seed_entry(entry, question) when is_map(entry) do
    entry
    |> put_entry_id(question)
    |> seed_entry_ids(Elements.list_questions(question.templateElements || []))
  end

  defp seed_entry(entry, _question), do: entry

  # An id already on the entry wins, then the record's own `id`, then a
  # generated one.
  defp put_entry_id(entry, question) do
    cond do
      not generate_ids?(question) -> entry
      present?(Map.get(entry, @id_field)) -> entry
      present?(Map.get(entry, "id")) -> Map.put(entry, @id_field, to_string(entry["id"]))
      true -> Map.put(entry, @id_field, Ecto.UUID.generate())
    end
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true

  # The id is cast as an ordinary template field so it round-trips with the
  # entry, but it is not part of templateElements — the renderer emits its
  # own hidden input rather than a labelled control.
  defp template_elements(question) do
    elements = question.templateElements || []

    if generate_ids?(question) do
      elements ++ [%Instance.Question{name: @id_field, type: "text"}]
    else
      elements
    end
  end

  @doc """
  Converts indexed-map values (as submitted by the browser) into ordered
  entry lists for every paneldynamic question, so the `{:array, :map}` cast
  succeeds and `changeset.params` holds a stable shape.
  """
  def normalize_params(params, questions) do
    questions
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(params, fn question, acc ->
      case Map.get(acc, question.name) do
        nil -> acc
        value -> Map.put(acc, question.name, entries(value))
      end
    end)
  end

  @doc """
  Resolves the paneldynamic question at a dot-separated entry path.

  Path segments alternate question names and entry indexes (`"addresses"`,
  or `"contacts.0.phones"` when nested). Each name resolves within its own
  scope — the top-level elements for the first segment, then each matched
  question's `templateElements` — so questions in different scopes may
  share a name. Returns `nil` when the path doesn't resolve.
  """
  def find_question(elements, path) do
    Elements.get_question_by_path(elements, path)
  end

  @doc """
  Validates every paneldynamic question on an already-cast parent changeset:
  entry changesets (validity propagates to the parent), `isRequired`,
  `minPanelCount`/`maxPanelCount`, and replaces the raw cast value with each
  entry's applied data.
  """
  def validate(changeset, questions, opts) do
    questions
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(changeset, fn question, acc ->
      validate_question(acc, question, opts)
    end)
  end

  defp validate_question(changeset, question, opts) do
    field = String.to_atom(question.name)
    children = entry_changesets(question, changeset.params, opts)

    changeset
    |> put_applied_entries(question, field, children)
    |> validate_required_entries(question, field, children)
    |> validate_entry_count(question, field)
    |> validate_entry_changesets(field, children)
  end

  # Replace the raw cast value (string-keyed maps straight from the browser,
  # including `_unused_` bookkeeping keys) with each entry changeset's applied
  # data, so apply_changes on the parent yields clean, typed nested maps.
  defp put_applied_entries(changeset, question, field, children) do
    if Map.has_key?(changeset.params, question.name) do
      applied = Enum.map(children, &Ecto.Changeset.apply_changes/1)
      Ecto.Changeset.put_change(changeset, field, applied)
    else
      changeset
    end
  end

  # Ecto's validate_required treats an empty list as present, so required
  # paneldynamic questions are enforced here instead (see
  # DynamicForm.Changeset.get_required_fields/2).
  defp validate_required_entries(changeset, %Instance.Question{isRequired: true}, field, []) do
    Ecto.Changeset.add_error(changeset, field, "can't be blank", validation: :required)
  end

  defp validate_required_entries(changeset, _question, _field, _children), do: changeset

  defp validate_entry_count(changeset, question, field) do
    changeset
    |> maybe_validate_length(field, :min, question.minPanelCount)
    |> maybe_validate_length(field, :max, question.maxPanelCount)
  end

  defp maybe_validate_length(changeset, _field, _key, nil), do: changeset
  defp maybe_validate_length(changeset, _field, :min, 0), do: changeset

  defp maybe_validate_length(changeset, field, key, value) do
    Ecto.Changeset.validate_length(changeset, field, [{key, value}])
  end

  # An invalid entry marks the parent invalid. The error carries a
  # `:paneldynamic` marker so the renderer can suppress it — each entry
  # renders its own field errors inline.
  defp validate_entry_changesets(changeset, field, children) do
    if Enum.all?(children, & &1.valid?) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, field, "is invalid", validation: :paneldynamic)
    end
  end

  defp panel_prefixed(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> panel_prefixed()
  end

  defp panel_prefixed(entry) do
    Map.new(entry, fn {key, value} -> {"panel.#{key}", value} end)
  end

  # Enforce keyName uniqueness across entries: any entry repeating another
  # entry's value for the key field gets an error on that field.
  defp apply_key_duplication(children, %Instance.Question{keyName: key_name} = question)
       when is_binary(key_name) and key_name != "" do
    field = String.to_atom(key_name)
    message = question.keyDuplicationError || "value must be unique"

    values = Enum.map(children, &Ecto.Changeset.get_field(&1, field))

    duplicated =
      values
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.frequencies()
      |> Enum.filter(fn {_value, count} -> count > 1 end)
      |> Enum.map(fn {value, _count} -> value end)

    Enum.zip_with(children, values, fn child, value ->
      if value in duplicated do
        Ecto.Changeset.add_error(child, field, message, validation: :key_duplication)
      else
        child
      end
    end)
  end

  defp apply_key_duplication(children, _question), do: children
end
