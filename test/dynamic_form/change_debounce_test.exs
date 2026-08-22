defmodule DynamicForm.ChangeDebounceTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.Instance
  alias DynamicForm.RendererLive

  @instance %Instance{
    id: "signup",
    elements: [
      %Instance.Question{name: "username", type: "text", title: "Username", isRequired: true}
    ]
  }

  # LiveComponents run inside their parent LiveView's process, so the
  # component's own callbacks can be driven directly against a bare socket:
  # `send_update_after/3` schedules its message to `self()`, which here is the
  # test process.
  defp mount_component(overrides \\ []) do
    assigns =
      [id: "signup", instance: @instance]
      |> Keyword.merge(overrides)
      |> Map.new()

    {:ok, socket} = RendererLive.update(assigns, %Phoenix.LiveView.Socket{})

    socket
  end

  defp validate(socket, params) do
    {:noreply, socket} =
      RendererLive.handle_event("validate", %{"dynamic_form" => params}, socket)

    socket
  end

  defp submit(socket, params) do
    {:noreply, socket} = RendererLive.handle_event("submit", %{"dynamic_form" => params}, socket)

    socket
  end

  # Deliver a debounced run the way the parent LiveView does when the timer
  # fires: `send_update_after/3` messages the process, which routes the
  # assigns into the component's `update/2`.
  defp deliver_scheduled_run(socket) do
    assert_receive {:phoenix, :send_update, {{RendererLive, "signup"}, assigns}}

    {:ok, socket} = RendererLive.update(assigns, socket)

    socket
  end

  # An on_change callback that reports every run to the test process and
  # rejects the reserved username.
  defp reporting_callback do
    test_pid = self()

    fn payload ->
      send(test_pid, {:on_change, payload.data[:username]})

      if payload.data[:username] == "taken" do
        DynamicForm.Payload.add_error(payload, :username, "is already taken")
      else
        payload
      end
    end
  end

  defp errors(socket) do
    Enum.map(socket.assigns.changeset.errors, fn {field, {message, _opts}} -> {field, message} end)
  end

  describe "without change_debounce_in_ms" do
    test "on_change runs inline on every change" do
      socket = mount_component(on_change: reporting_callback())

      socket = validate(socket, %{"username" => "ta"})
      assert_received {:on_change, "ta"}

      socket = validate(socket, %{"username" => "taken"})
      assert_received {:on_change, "taken"}

      assert errors(socket) == [username: "is already taken"]
      refute_received {:phoenix, :send_update, _}
    end

    test "an interval of zero runs the callback inline" do
      socket = mount_component(on_change: reporting_callback(), change_debounce_in_ms: 0)

      socket = validate(socket, %{"username" => "taken"})

      assert_received {:on_change, "taken"}
      assert errors(socket) == [username: "is already taken"]
      refute_received {:phoenix, :send_update, _}
    end

    test "a form without on_change validates without scheduling anything" do
      socket = mount_component() |> validate(%{"username" => ""})

      assert errors(socket) == [username: "can't be blank"]
      refute_received {:phoenix, :send_update, _}
    end

    test "an interval with nothing to defer is inert" do
      socket = mount_component(change_debounce_in_ms: 50) |> validate(%{"username" => ""})

      assert errors(socket) == [username: "can't be blank"]
      refute_received {:phoenix, :send_update, _}
    end
  end

  describe "with change_debounce_in_ms" do
    test "the change renders the built-in validations and defers the callback" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
        |> validate(%{"username" => ""})

      refute_received {:on_change, _}
      assert errors(socket) == [username: "can't be blank"]

      socket = deliver_scheduled_run(socket)

      assert_received {:on_change, nil}
      assert errors(socket) == [username: "can't be blank"]
    end

    test "the deferred run adds the callback's errors" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
        |> validate(%{"username" => "taken"})

      assert errors(socket) == []

      socket = deliver_scheduled_run(socket)

      assert_received {:on_change, "taken"}
      assert errors(socket) == [username: "is already taken"]
    end

    test "the callback runs once for a burst of changes, against the latest data" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
        |> validate(%{"username" => "ta"})
        |> validate(%{"username" => "tak"})
        |> validate(%{"username" => "taken"})

      # Every change but the last is superseded: canceled timers deliver
      # nothing, and a run already in the mailbox is fenced by its token.
      socket = drain_scheduled_runs(socket)

      assert_received {:on_change, "taken"}
      refute_received {:on_change, _}
      assert errors(socket) == [username: "is already taken"]
    end

    test "a run already in the mailbox is dropped when a later change supersedes it" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 1)
        |> validate(%{"username" => "taken"})

      # Let the timer fire so its run is already queued: canceling a timer
      # can't recall a delivered message, so only the token drops this run.
      Process.sleep(20)

      socket =
        socket
        |> validate(%{"username" => "free"})
        |> drain_scheduled_runs()

      assert_received {:on_change, "free"}
      refute_received {:on_change, _}
      assert errors(socket) == []
    end

    test "the pending run is dropped when the callback's errors no longer apply" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
        |> validate(%{"username" => "taken"})

      socket = deliver_scheduled_run(socket)
      assert errors(socket) == [username: "is already taken"]

      # Typing clears the callback's error until the deferred run re-adds it.
      socket = validate(socket, %{"username" => "free"})
      assert errors(socket) == []

      socket = deliver_scheduled_run(socket)
      assert_received {:on_change, "free"}
      assert errors(socket) == []
    end

    test "submitting runs the callback inline and supersedes the pending run" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
        |> validate(%{"username" => "taken"})

      socket = submit(socket, %{"username" => "taken"})

      assert_received {:on_change, "taken"}
      assert errors(socket) == [username: "is already taken"]
      refute_received {:dynamic_form, _, _}

      # The change's pending run is a no-op once delivered.
      socket = drain_scheduled_runs(socket)

      refute_received {:on_change, _}
      assert errors(socket) == [username: "is already taken"]
    end

    test "a valid submit still messages the parent LiveView" do
      mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
      |> validate(%{"username" => "free"})
      |> submit(%{"username" => "free"})

      assert_received {:dynamic_form, :success, %DynamicForm.Payload{data: %{username: "free"}}}
    end

    test "a new form definition supersedes the pending run" do
      socket =
        mount_component(on_change: reporting_callback(), change_debounce_in_ms: 50)
        |> validate(%{"username" => "taken"})

      # A parent re-render with different initial data rebuilds the form.
      {:ok, socket} =
        RendererLive.update(
          %{id: "signup", instance: @instance, data: %{"username" => "seeded"}},
          socket
        )

      socket = drain_scheduled_runs(socket)

      refute_received {:on_change, _}
      assert errors(socket) == []
    end

    test "a non-integer interval raises" do
      socket = mount_component(on_change: reporting_callback(), change_debounce_in_ms: "300")

      assert_raise ArgumentError,
                   ~r/change_debounce_in_ms must be a non-negative integer/,
                   fn ->
                     validate(socket, %{"username" => "taken"})
                   end
    end

    test "a negative interval raises" do
      socket = mount_component(on_change: reporting_callback(), change_debounce_in_ms: -1)

      assert_raise ArgumentError,
                   ~r/change_debounce_in_ms must be a non-negative integer/,
                   fn ->
                     validate(socket, %{"username" => "taken"})
                   end
    end
  end

  describe "DynamicForm.form/1 validation" do
    test "render-only mode rejects the interval" do
      form =
        {%{}, %{username: :string}}
        |> Ecto.Changeset.cast(%{}, [:username])
        |> Phoenix.Component.to_form(as: "dynamic_form")

      assert_raise ArgumentError, ~r/Remove: on_change, change_debounce_in_ms/, fn ->
        render_component(&DynamicForm.form/1,
          id: "signup",
          instance: @instance,
          render_only: true,
          form: form,
          on_change: fn payload -> payload end,
          change_debounce_in_ms: 300
        )
      end
    end
  end

  # Deliver every scheduled run sitting in the mailbox, in order.
  defp drain_scheduled_runs(socket) do
    receive do
      {:phoenix, :send_update, {{RendererLive, "signup"}, assigns}} ->
        {:ok, socket} = RendererLive.update(assigns, socket)
        drain_scheduled_runs(socket)
    after
      100 -> socket
    end
  end
end
