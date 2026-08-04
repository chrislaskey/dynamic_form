defmodule Demo.Submissions do
  @moduledoc """
  A stand-in Phoenix context for form submissions.

  Demonstrates the `on_valid_submit` contract: a 1-arity function receiving
  the form data and returning `{:ok, result}` or `{:error, changeset | reason}`.
  A real application would insert a record, send an email, call an API, etc.
  """

  require Logger

  @doc """
  "Creates" a submission by logging it.

  Returns `{:error, changeset}` when the email is `taken@example.com` to
  demonstrate how context-level errors (like uniqueness violations) render
  on the form.
  """
  def create(data) do
    if Map.get(data, :email) == "taken@example.com" do
      {:error, email_taken_changeset(data)}
    else
      Logger.info("Form submitted successfully: #{inspect(data)}")
      {:ok, %{message: "Form submitted successfully!", data: data}}
    end
  end

  # A context function typically returns its schema's changeset; the library
  # copies the errors onto the form's changeset by field name.
  defp email_taken_changeset(data) do
    {data, %{email: :string}}
    |> Ecto.Changeset.cast(%{}, [])
    |> Ecto.Changeset.add_error(:email, "has already been taken")
  end
end
