defmodule DynamicForm.ReadOnlyTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.{Instance, RendererLive}

  defp mount_component(instance, data) do
    {:ok, socket} =
      RendererLive.update(
        %{id: "form", instance: instance, data: data},
        %Phoenix.LiveView.Socket{}
      )

    socket
  end

  defp validate(socket, params) do
    {:noreply, socket} =
      RendererLive.handle_event("validate", %{"dynamic_form" => params}, socket)

    socket
  end

  defp data(socket), do: Ecto.Changeset.apply_changes(socket.assigns.changeset)

  describe "inside a nested entry" do
    @instance %Instance{
      id: "school",
      elements: [
        %Instance.Question{
          name: "staff",
          type: "paneldynamic",
          title: "Staff",
          templateElements: [
            %Instance.Question{name: "ref", type: "text", title: "Ref", readOnly: true},
            %Instance.Question{
              name: "role",
              type: "dropdown",
              title: "Role",
              choices: ["lead", "aide"],
              readOnly: true
            },
            %Instance.Question{name: "name", type: "text", title: "Name"}
          ]
        }
      ]
    }

    @seeded %{"staff" => [%{"ref" => "abc-123", "role" => "lead", "name" => "Ada"}]}

    test "a read-only text value survives a change to a sibling field" do
      # The browser submits readonly inputs, so "ref" comes back with the entry.
      socket =
        @instance
        |> mount_component(@seeded)
        |> validate(%{
          "staff" => %{"0" => %{"ref" => "abc-123", "name" => "Ada Lovelace"}}
        })

      assert %{staff: [%{ref: "abc-123", name: "Ada Lovelace"}]} = data(socket)
    end

    test "a read-only choice value survives through its hidden input" do
      # Disabled selects submit nothing; the hidden mirror carries the value.
      socket =
        @instance
        |> mount_component(@seeded)
        |> validate(%{
          "staff" => %{"0" => %{"role" => "lead", "name" => "Ada Lovelace"}}
        })

      assert %{staff: [%{role: "lead"}]} = data(socket)
    end

    test "the values are still gone when the entry omits them entirely" do
      # Guards the test above against passing for the wrong reason: nothing
      # restores a value the browser never sent.
      socket =
        @instance
        |> mount_component(@seeded)
        |> validate(%{"staff" => %{"0" => %{"name" => "Ada Lovelace"}}})

      refute match?(%{staff: [%{ref: _}]}, data(socket))
    end
  end

  describe "inside a group" do
    @grouped %Instance{
      id: "school",
      elements: [
        %Instance.Element{
          name: "billing",
          type: "panel",
          title: "Billing",
          elements: [
            %Instance.Question{
              name: "plan",
              type: "dropdown",
              title: "Plan",
              choices: ["monthly", "annual"],
              readOnly: true
            },
            %Instance.Question{name: "contact", type: "text", title: "Contact"},
            %Instance.Question{
              name: "locked",
              type: "dropdown",
              title: "Locked",
              choices: ["monthly", "annual"],
              readOnly: true,
              enableIf: "{contact} = 'unlocked'"
            }
          ]
        }
      ]
    }

    test "a read-only choice question still renders its hidden input" do
      html = render_grouped(%{"plan" => "annual"})

      # The disabled select submits nothing, so the mirror carries the value.
      assert html =~ ~s(<input type="hidden" name="dynamic_form[plan]" value="annual">)
    end

    test "a question disabled by enable_if gets no hidden input" do
      html = render_grouped(%{"locked" => "annual", "contact" => "no"})

      refute html =~ ~s(name="dynamic_form[locked]" value="annual")
    end

    defp render_grouped(params) do
      render_component(&DynamicForm.Renderer.render/1,
        instance: @grouped,
        form:
          @grouped
          |> DynamicForm.Changeset.create_changeset(params)
          |> Phoenix.Component.to_form(as: "dynamic_form"),
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
    end
  end

  describe "at the top level" do
    @top %Instance{
      id: "profile",
      elements: [
        %Instance.Question{name: "id", type: "text", title: "ID", readOnly: true},
        %Instance.Question{name: "name", type: "text", title: "Name"},
        %Instance.Question{
          name: "plan",
          type: "text",
          title: "Plan",
          enableIf: "{name} = 'unlocked'"
        }
      ]
    }

    test "a read-only value submits with the form" do
      socket =
        @top
        |> mount_component(%{"id" => "u-1", "name" => "Ada"})
        |> validate(%{"id" => "u-1", "name" => "Ada Lovelace"})

      assert %{id: "u-1", name: "Ada Lovelace"} = data(socket)
    end

    test "an enable_if disabled question stays excluded" do
      html =
        render_component(&DynamicForm.Renderer.render/1,
          instance: @top,
          form:
            @top
            |> DynamicForm.Changeset.create_changeset(%{"plan" => "pro"})
            |> Phoenix.Component.to_form(as: "dynamic_form"),
          submit_text: "Submit",
          phx_submit: "submit",
          phx_change: "validate",
          target: nil,
          form_id: "profile-form",
          disabled: false,
          hide_submit: false,
          gettext: DynamicForm.Gettext,
          uploads: %{},
          parent_id: nil
        )

      # Disabled because of enableIf, and no hidden input smuggling the value
      # back into the params.
      assert html =~ "disabled"
      refute html =~ ~s(name="dynamic_form[plan]" value="pro")
    end
  end
end
