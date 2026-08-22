defmodule DynamicForm.Helpers.Form do
  @moduledoc """
  Plumbing for the `Phoenix.HTML.Form` structs the library renders against.

  Internal module — not part of the public API.
  """

  @doc """
  The form's current raw params — the changeset's changes — or an empty map
  when the form's source has none.
  """
  def get_params(form) do
    form.source.changes
  rescue
    _ -> %{}
  end

  @doc """
  The whole form's current values: the applied changeset when the form is
  changeset-backed. Render-only mode renders against a parent-owned form, so
  a non-changeset source falls back to its params.
  """
  def get_applied_data(%Phoenix.HTML.Form{source: %Ecto.Changeset{} = changeset}) do
    Ecto.Changeset.apply_changes(changeset)
  end

  def get_applied_data(%Phoenix.HTML.Form{params: params}), do: params

  @doc """
  Attaches the form-level data to the value a slot body receives. It rides in
  the form's options, which is private plumbing — `DynamicForm.form_data/1`
  is the contract. Only slot bodies are decorated: the root form is rendered
  by `Phoenix.Component.form/1`, which spreads its options onto the `<form>`
  tag.
  """
  def put_data(%Phoenix.HTML.FormField{} = field, data) do
    %{field | form: put_data(field.form, data)}
  end

  def put_data(%Phoenix.HTML.Form{} = form, data) do
    %{form | options: Keyword.put(form.options, :form_data, data)}
  end
end
