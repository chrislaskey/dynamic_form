defmodule DynamicForm.SendMessageOnTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.Instance
  alias DynamicForm.Payload
  alias DynamicForm.Renderer

  @instance %Instance{
    id: "signup",
    elements: [
      %Instance.Question{name: "username", type: "text", title: "Username", isRequired: true}
    ]
  }

  @nested_instance %Instance{
    id: "contacts",
    elements: [
      %Instance.Question{
        name: "phones",
        type: "paneldynamic",
        title: "Phones",
        templateElements: [
          %Instance.Question{name: "number", type: "text", title: "Number"}
        ]
      }
    ]
  }

  # LiveComponents run inside their parent LiveView's process, so the
  # component's callbacks can be driven directly against a bare socket and the
  # messages it sends land in the test process.
  defp mount_component(overrides \\ []) do
    assigns =
      [id: "signup", instance: @instance]
      |> Keyword.merge(overrides)
      |> Map.new()

    {:ok, socket} = Renderer.LiveComponent.update(assigns, %Phoenix.LiveView.Socket{})

    socket
  end

  defp validate(socket, params) do
    {:noreply, socket} =
      Renderer.LiveComponent.handle_event("validate", %{"dynamic_form" => params}, socket)

    socket
  end

  defp submit(socket, params) do
    {:noreply, socket} =
      Renderer.LiveComponent.handle_event("submit", %{"dynamic_form" => params}, socket)

    socket
  end

  # Every {:dynamic_form, event, payload} message in the mailbox, in order.
  defp received_events do
    receive do
      {:dynamic_form, event, %Payload{}} -> [event | received_events()]
    after
      0 -> []
    end
  end

  describe "default" do
    test "only a valid submission messages the parent" do
      mount_component()
      |> validate(%{"username" => ""})
      |> submit(%{"username" => ""})

      assert received_events() == []

      mount_component()
      |> validate(%{"username" => "ada"})
      |> submit(%{"username" => "ada"})

      assert received_events() == [:success]
    end
  end

  describe ":change" do
    test "every change messages the parent with the current payload" do
      mount_component(send_message_on: [:change])
      |> validate(%{"username" => "ad"})
      |> validate(%{"username" => "ada"})

      assert_received {:dynamic_form, :change, %Payload{data: %{username: "ad"}}}
      assert_received {:dynamic_form, :change, %Payload{data: %{username: "ada"}}}
    end

    test "the payload carries the on_change callback's errors" do
      callback = fn payload -> Payload.add_error(payload, :username, "is already taken") end

      mount_component(send_message_on: [:change], on_change: callback)
      |> validate(%{"username" => "taken"})

      assert_received {:dynamic_form, :change, payload}
      refute Payload.valid?(payload)
      assert [username: {"is already taken", _}] = payload.changeset.errors
    end

    test "adding and removing a nested entry messages the parent" do
      socket =
        mount_component(id: "contacts", instance: @nested_instance, send_message_on: [:change])

      {:noreply, socket} =
        Renderer.LiveComponent.handle_event("add_nested_entry", %{"path" => "phones"}, socket)

      assert_received {:dynamic_form, :change, %Payload{data: %{phones: [_entry]}}}

      {:noreply, _socket} =
        Renderer.LiveComponent.handle_event(
          "remove_nested_entry",
          %{"path" => "phones", "index" => "0"},
          socket
        )

      assert_received {:dynamic_form, :change, %Payload{data: %{phones: []}}}
    end

    test "the message rides the debounce interval" do
      socket =
        mount_component(send_message_on: [:change], change_debounce_in_ms: 50)
        |> validate(%{"username" => "ad"})
        |> validate(%{"username" => "ada"})

      assert received_events() == []

      assert_receive {:phoenix, :send_update, {{Renderer.LiveComponent, "signup"}, assigns}}
      {:ok, _socket} = Renderer.LiveComponent.update(assigns, socket)

      assert_received {:dynamic_form, :change, %Payload{data: %{username: "ada"}}}
      assert received_events() == []
    end
  end

  describe ":submit" do
    test "an invalid submission messages the parent" do
      mount_component(send_message_on: [:submit])
      |> submit(%{"username" => ""})

      assert_received {:dynamic_form, :submit, payload}
      refute Payload.valid?(payload)
    end

    test "the payload carries the on_submit callback's extra" do
      callback = fn payload -> Payload.put_extra(payload, :normalized, "ADA") end

      mount_component(send_message_on: [:submit], on_submit: callback)
      |> submit(%{"username" => "ada"})

      assert_received {:dynamic_form, :submit, %Payload{extra: %{normalized: "ADA"}}}
    end
  end

  describe "combinations" do
    test "a valid submit delivers change, submit, and success in order" do
      mount_component(send_message_on: [:success, :change, :submit])
      |> submit(%{"username" => "ada"})

      assert received_events() == [:change, :submit, :success]
    end

    test "an invalid submit stops after submit" do
      mount_component(send_message_on: [:success, :change, :submit])
      |> submit(%{"username" => ""})

      assert received_events() == [:change, :submit]
    end

    test "an empty list silences the form" do
      mount_component(send_message_on: [])
      |> validate(%{"username" => "ada"})
      |> submit(%{"username" => "ada"})

      assert received_events() == []
    end
  end

  describe "on_success" do
    test "replaces the default success message" do
      test_pid = self()

      mount_component(on_success: fn payload -> send(test_pid, {:done, payload.data}) end)
      |> submit(%{"username" => "ada"})

      assert_received {:done, %{username: "ada"}}
      assert received_events() == []
    end

    test "still allows change and submit messages" do
      mount_component(
        on_success: fn _payload -> :ok end,
        send_message_on: [:change, :submit]
      )
      |> submit(%{"username" => "ada"})

      assert received_events() == [:change, :submit]
    end

    test "raises when :success is also requested" do
      assert_raise ArgumentError, ~r/on_success replaces the success message/, fn ->
        mount_component(on_success: fn _payload -> :ok end, send_message_on: [:success])
      end
    end
  end

  describe "validation" do
    test "an unknown event raises" do
      assert_raise ArgumentError, ~r/unknown events: \[:done\]/, fn ->
        mount_component(send_message_on: [:success, :done])
      end
    end

    test "a non-list raises" do
      assert_raise ArgumentError, ~r/send_message_on must be a list/, fn ->
        mount_component(send_message_on: :change)
      end
    end

    test "render-only mode rejects the attribute" do
      form =
        {%{}, %{username: :string}}
        |> Ecto.Changeset.cast(%{}, [:username])
        |> Phoenix.Component.to_form(as: "dynamic_form")

      assert_raise ArgumentError, ~r/Remove: send_message_on/, fn ->
        render_component(&DynamicForm.form/1,
          id: "signup",
          instance: @instance,
          render_only: true,
          form: form,
          send_message_on: [:change]
        )
      end
    end
  end
end
