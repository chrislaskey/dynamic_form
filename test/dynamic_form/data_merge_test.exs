defmodule DynamicForm.DataMergeTest do
  use ExUnit.Case, async: true

  alias DynamicForm.{Instance, RendererLive}

  # A section the user can hide, plus a question disabled by the same switch.
  @instance %Instance{
    id: "tuition",
    elements: [
      %Instance.Question{name: "uses_age_groups", type: "boolean", title: "Sort by age?"},
      %Instance.Question{
        name: "notes",
        type: "text",
        title: "Notes",
        enableIf: "{uses_age_groups} = true"
      },
      %Instance.Question{
        name: "age_groups",
        type: "paneldynamic",
        title: "Age groups",
        visibleIf: "{uses_age_groups} = true",
        templateElements: [
          %Instance.Question{name: "min", type: "text", title: "From"},
          %Instance.Question{name: "max", type: "text", title: "To"}
        ]
      }
    ]
  }

  @data %{
    "id" => "record-1",
    "uses_age_groups" => true,
    "notes" => "loaded note",
    "age_groups" => [%{"id" => "ag-1", "min" => "6", "max" => "12"}]
  }

  defp mount_component(data \\ @data, instance \\ @instance) do
    {:ok, socket} =
      RendererLive.update(
        %{id: "tuition", instance: instance, data: data},
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

  describe "a section hidden after being edited" do
    test "keeps the user's edits rather than rewinding to the loaded data" do
      socket =
        mount_component()
        |> validate(%{
          "uses_age_groups" => "true",
          "age_groups" => %{
            "0" => %{"dynamic_form_id" => "ag-1", "min" => "3", "max" => "12"},
            "1" => %{"dynamic_form_id" => "ag-2", "min" => "12", "max" => "24"}
          }
        })

      # Unticking hides the section, so the browser submits nothing for it.
      socket = validate(socket, %{"uses_age_groups" => "false"})

      assert [%{min: "3", max: "12"}, %{min: "12", max: "24"}] = data(socket).age_groups
    end

    test "keeps its entries' ids, so references to them stay valid" do
      socket =
        mount_component()
        |> validate(%{
          "uses_age_groups" => "true",
          "age_groups" => %{"0" => %{"dynamic_form_id" => "ag-1", "min" => "6", "max" => "12"}}
        })
        |> validate(%{"uses_age_groups" => "false"})

      assert [%{dynamic_form_id: "ag-1"}] = data(socket).age_groups
    end

    test "an entry removed before hiding stays removed" do
      socket =
        mount_component()
        |> validate(%{
          "uses_age_groups" => "true",
          "age_groups" => %{"__empty__" => ""}
        })
        |> validate(%{"uses_age_groups" => "false"})

      assert data(socket).age_groups == []
    end
  end

  describe "values the browser never submits" do
    test "an enable_if disabled question keeps what it last held" do
      socket =
        mount_component()
        |> validate(%{"uses_age_groups" => "true", "notes" => "edited note"})
        # Disabling it stops the browser submitting it.
        |> validate(%{"uses_age_groups" => "false"})

      assert data(socket).notes == "edited note"
    end

    test "extra keys with no matching question survive" do
      socket = mount_component() |> validate(%{"uses_age_groups" => "false"})

      assert socket.assigns.changeset.params["id"] == "record-1"
    end
  end

  describe "the parent passing different data" do
    test "still resets the form, overriding what it was holding" do
      socket = mount_component() |> validate(%{"notes" => "edited note"})

      {:ok, socket} =
        RendererLive.update(
          %{
            id: "tuition",
            instance: @instance,
            data: %{@data | "notes" => "a different record"}
          },
          socket
        )

      assert data(socket).notes == "a different record"
    end
  end
end
