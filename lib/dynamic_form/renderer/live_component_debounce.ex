defmodule DynamicForm.Renderer.LiveComponent.Debounce do
  @moduledoc """
  Timer and token mechanics for debouncing `DynamicForm.Renderer.LiveComponent`'s
  change pass (`change_debounce_in_ms`).

  LiveComponents have no `handle_info/2`, so a scheduled run arrives back
  through `update/2` as a `:run_change` action carrying a token. Canceling a
  timer can't recall a message already sitting in the process mailbox, so the
  token is what makes a superseded run a no-op when it arrives: `cancel/1`
  bumps it, and `current?/2` compares.

  Internal module — not part of the public API.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [send_update_after: 3]

  @doc """
  The debounce interval for the change pass, or `nil` when it runs inline:
  nothing to defer, no interval, or an interval of zero.
  """
  def interval(socket) do
    case socket.assigns[:change_debounce_in_ms] do
      nil ->
        nil

      0 ->
        nil

      interval when is_integer(interval) and interval > 0 ->
        if deferrable_change?(socket), do: interval, else: nil

      other ->
        raise ArgumentError,
              "change_debounce_in_ms must be a non-negative integer of milliseconds, " <>
                "got: #{inspect(other)}"
    end
  end

  @doc """
  Debounces the change pass: drops the run this change supersedes and
  schedules a fresh one.
  """
  def schedule(socket, interval) do
    socket = cancel(socket)
    token = socket.assigns.change_token

    timer =
      send_update_after(
        DynamicForm.Renderer.LiveComponent,
        [id: socket.assigns.id, action: :run_change, token: token],
        interval
      )

    assign(socket, :change_timer, timer)
  end

  @doc """
  Drops any pending debounced run and issues the token the next one will
  carry. Canceling the timer is the fast path; the token is what makes a
  run already in the mailbox a no-op when it arrives.
  """
  def cancel(socket) do
    case socket.assigns[:change_timer] do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end

    socket
    |> assign(:change_timer, nil)
    |> assign(:change_token, (socket.assigns[:change_token] || 0) + 1)
  end

  @doc """
  Whether a delivered run's token matches the one currently issued — a
  mismatch means the run was superseded and must be dropped.
  """
  def current?(socket, token) do
    token == socket.assigns[:change_token]
  end

  defp deferrable_change?(socket) do
    not is_nil(socket.assigns[:on_change]) or :change in socket.assigns.send_message_on
  end
end
