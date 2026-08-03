defmodule Demo.TestBackend do
  @moduledoc """
  A simple test backend for DynamicForm that just logs submissions.
  This is for demonstration purposes only.
  """

  @behaviour DynamicForm.Backend

  require Logger

  @impl DynamicForm.Backend
  def submit(data, changeset, _config) do
    # Check if built-in validations passed
    if not changeset.valid? do
      Logger.warning("Form submission with invalid changeset: #{inspect(changeset.errors)}")
      {:halt, changeset}
    else
      Logger.info("Form submitted successfully: #{inspect(data)}")
      {:cont, %{message: "Form submitted successfully!", data: data}}
    end
  end

  @impl DynamicForm.Backend
  def validate_config(_config) do
    # No config required for test backend
    :ok
  end
end
