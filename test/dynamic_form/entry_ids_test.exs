defmodule DynamicForm.EntryIdsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.{Instance, NestedForms, RendererLive}

  defp instance(overrides \\ []) do
    question =
      struct!(
        %Instance.Question{
          name: "staff",
          type: "paneldynamic",
          title: "Staff",
          templateElements: [%Instance.Question{name: "name", type: "text", title: "Name"}]
        },
        overrides
      )

    %Instance{id: "school", elements: [question]}
  end

  defp mount_component(instance, data \\ %{}) do
    {:ok, socket} =
      RendererLive.update(
        %{id: "school", instance: instance, data: data},
        %Phoenix.LiveView.Socket{}
      )

    socket
  end

  defp validate(socket, params) do
    {:noreply, socket} =
      RendererLive.handle_event("validate", %{"dynamic_form" => params}, socket)

    socket
  end

  defp entries(socket) do
    socket.assigns.changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.get(:staff, [])
  end

  defp ids(socket), do: Enum.map(entries(socket), & &1[:dynamic_form_id])

  describe "seeding" do
    test "an entry from stored data adopts its own id" do
      socket =
        mount_component(instance(), %{
          "staff" => [%{"id" => 42, "name" => "Ada"}, %{"id" => "u-7", "name" => "Grace"}]
        })

      assert ids(socket) == ["42", "u-7"]
    end

    test "an entry without an id gets a generated one" do
      socket = mount_component(instance(), %{"staff" => [%{"name" => "Ada"}]})

      assert [id] = ids(socket)
      assert is_binary(id)
      refute id == ""
    end

    test "seeded entries each get their own id" do
      socket = mount_component(instance(panelCount: 3))

      assert [_, _, _] = ids = ids(socket)
      assert length(Enum.uniq(ids)) == 3
    end

    test "an existing dynamic_form_id is kept as-is" do
      socket =
        mount_component(instance(), %{
          "staff" => [%{"dynamic_form_id" => "kept", "id" => 42, "name" => "Ada"}]
        })

      assert ids(socket) == ["kept"]
    end

    test "generate_ids false seeds nothing" do
      socket =
        mount_component(instance(generateIds: false), %{"staff" => [%{"name" => "Ada"}]})

      assert ids(socket) == [nil]
    end
  end

  describe "round trip" do
    test "the id survives edits to the entry" do
      socket = mount_component(instance(), %{"staff" => [%{"id" => 42, "name" => "Ada"}]})
      [id] = ids(socket)

      # The hidden input submits the id back with the rest of the entry.
      socket =
        validate(socket, %{
          "staff" => %{"0" => %{"dynamic_form_id" => id, "name" => "Ada Lovelace"}}
        })

      assert ids(socket) == [id]
      assert [%{name: "Ada Lovelace"}] = entries(socket)
    end

    test "the id renders as a hidden input inside the entry" do
      socket = mount_component(instance(), %{"staff" => [%{"id" => 42, "name" => "Ada"}]})

      html =
        render_component(&DynamicForm.Renderer.render/1,
          instance: socket.assigns.instance,
          form: socket.assigns.form,
          submit_text: "Submit",
          phx_submit: "submit",
          phx_change: "validate",
          target: nil,
          form_id: "school-form",
          disabled: false,
          hide_submit: false,
          gettext: DynamicForm.Gettext,
          uploads: %{},
          parent_id: nil
        )

      assert html =~
               ~s(<input type="hidden" name="dynamic_form[staff][0][dynamic_form_id]" value="42">)
    end

    test "a newly added entry gets an id that survives the next change" do
      socket = mount_component(instance())

      {:noreply, socket} =
        RendererLive.handle_event("add_nested_entry", %{"path" => "staff"}, socket)

      assert [id] = ids(socket)
      assert is_binary(id)

      socket =
        validate(socket, %{"staff" => %{"0" => %{"dynamic_form_id" => id, "name" => "Ada"}}})

      assert ids(socket) == [id]
    end
  end

  describe "parent re-renders" do
    # Ids are seeded into the changeset's params, never into initial_data:
    # initial_data is compared on every parent re-render to decide whether the
    # form resets, so a fresh id per render would wipe in-progress input.
    test "an unchanged re-render keeps the id and in-progress input" do
      assigns = %{id: "school", instance: instance(), data: %{"staff" => [%{"name" => "Ada"}]}}

      {:ok, socket} = RendererLive.update(assigns, %Phoenix.LiveView.Socket{})
      [id] = ids(socket)

      socket =
        validate(socket, %{"staff" => %{"0" => %{"dynamic_form_id" => id, "name" => "Ada L"}}})

      {:ok, socket} = RendererLive.update(assigns, socket)

      assert ids(socket) == [id]
      assert [%{name: "Ada L"}] = entries(socket)
    end

    test "an unchanged re-render keeps a seeded entry's id" do
      assigns = %{id: "school", instance: instance(panelCount: 2)}

      {:ok, socket} = RendererLive.update(assigns, %Phoenix.LiveView.Socket{})
      seeded = ids(socket)

      {:ok, socket} = RendererLive.update(assigns, socket)

      assert ids(socket) == seeded
    end

    test "a title and description computed per render don't count as a change" do
      # What title={gettext("Staff")} does: the value is recomputed on every
      # parent render. Equal strings compare equal, so the form does not reset.
      translate = fn text -> String.trim(" " <> text <> " ") end

      assigns = fn ->
        %{
          id: "school",
          instance:
            instance(title: translate.("Staff"), description: translate.("Everyone on payroll")),
          data: %{"staff" => [%{"name" => "Ada"}]}
        }
      end

      {:ok, socket} = RendererLive.update(assigns.(), %Phoenix.LiveView.Socket{})
      [id] = ids(socket)

      socket =
        validate(socket, %{"staff" => %{"0" => %{"dynamic_form_id" => id, "name" => "Ada L"}}})

      {:ok, socket} = RendererLive.update(assigns.(), socket)

      assert ids(socket) == [id]
      assert [%{name: "Ada L"}] = entries(socket)
    end
  end

  describe "nested inside another nested form" do
    @deep %Instance{
      id: "org",
      elements: [
        %Instance.Question{
          name: "teams",
          type: "paneldynamic",
          title: "Teams",
          templateElements: [
            %Instance.Question{name: "name", type: "text", title: "Name"},
            %Instance.Question{
              name: "members",
              type: "paneldynamic",
              title: "Members",
              templateElements: [%Instance.Question{name: "name", type: "text", title: "Name"}]
            }
          ]
        }
      ]
    }

    test "entries at both levels are seeded" do
      socket =
        mount_component(@deep, %{
          "teams" => [
            %{"id" => "t-1", "name" => "Core", "members" => [%{"id" => "m-1", "name" => "Ada"}]}
          ]
        })

      assert [team] = Ecto.Changeset.apply_changes(socket.assigns.changeset).teams
      assert team[:dynamic_form_id] == "t-1"
      assert [%{dynamic_form_id: "m-1"}] = team[:members]
    end
  end

  describe "payload" do
    test "the id is part of the submitted data" do
      socket = mount_component(instance(), %{"staff" => [%{"id" => 42, "name" => "Ada"}]})

      {:noreply, _socket} =
        RendererLive.handle_event(
          "submit",
          %{
            "dynamic_form" => %{
              "staff" => %{"0" => %{"dynamic_form_id" => "42", "name" => "Ada"}}
            }
          },
          socket
        )

      assert_received {:dynamic_form, :success, payload}
      assert [%{dynamic_form_id: "42", name: "Ada"}] = payload.data.staff
    end
  end

  describe "id_field/0" do
    test "names the field the rest of the library uses" do
      assert NestedForms.id_field() == "dynamic_form_id"
    end
  end
end
