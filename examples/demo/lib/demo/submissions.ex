defmodule Demo.Submissions do
  @moduledoc """
  A stand-in Phoenix context for form submissions.

  `verify/1` demonstrates the canonical `on_submit` shape: a validation hook
  that runs on every submit — valid or not — batching expensive checks (here
  a fake uniqueness lookup) with the built-in errors into one complete error
  list. The action itself (`create/1`) belongs in the parent LiveView's
  `handle_info/2`, which only hears about valid submissions.
  """

  require Logger

  alias DynamicForm.Payload

  @doc """
  The `on_submit` callback: expensive, submit-only validation.

  Rejects the email `taken@example.com` to demonstrate a uniqueness-style
  check rendering on the form alongside the built-in errors.
  """
  def verify(payload) do
    if Map.get(payload.data, :email) == "taken@example.com" do
      Payload.add_error(payload, :email, "has already been taken")
    else
      payload
    end
  end

  @doc """
  "Creates" a submission by logging it.

  The side-effect half of the lifecycle — called from the parent LiveView's
  `handle_info/2` when a `{:dynamic_form, payload}` message arrives. A real
  application would insert a record, send an email, call an API, etc.
  """
  def create(data) do
    Logger.info("Form submitted successfully: #{inspect(data)}")
    {:ok, %{message: "Form submitted successfully!", data: data}}
  end
end
