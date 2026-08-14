defmodule DynamicForm.CarryForwardTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.{Instance, RendererLive}

  # Two nested forms: age groups, and programs that each pick which age
  # groups they serve — the motivating shape for carry forward.
  defp instance(overrides \\ []) do
    consuming =
      struct!(
        %Instance.Question{
          name: "age_group_ids",
          type: "checkbox",
          title: "Age groups",
          choicesFromQuestion: "age_groups",
          choiceTextsFromQuestion: "{min} - {max}"
        },
        overrides
      )

    %Instance{
      id: "tuition",
      elements: [
        %Instance.Question{
          name: "age_groups",
          type: "paneldynamic",
          title: "Age groups",
          templateElements: [
            %Instance.Question{name: "min", type: "text", title: "Min"},
            %Instance.Question{name: "max", type: "text", title: "Max"}
          ]
        },
        %Instance.Question{
          name: "programs",
          type: "paneldynamic",
          title: "Programs",
          templateElements: [
            %Instance.Question{name: "name", type: "text", title: "Name"},
            consuming
          ]
        }
      ]
    }
  end

  defp mount_component(instance, data) do
    {:ok, socket} =
      RendererLive.update(
        %{id: "tuition", instance: instance, data: data},
        %Phoenix.LiveView.Socket{}
      )

    socket
  end

  defp render_form(socket) do
    render_component(&DynamicForm.Renderer.render/1,
      instance: socket.assigns.instance,
      form: socket.assigns.form,
      submit_text: "Submit",
      phx_submit: "submit",
      phx_change: "validate",
      target: nil,
      form_id: "tuition-form",
      disabled: false,
      hide_submit: false,
      gettext: DynamicForm.Gettext,
      uploads: %{},
      parent_id: nil
    )
  end

  defp validate(socket, params) do
    {:noreply, socket} =
      RendererLive.handle_event("validate", %{"dynamic_form" => params}, socket)

    socket
  end

  defp data(socket), do: Ecto.Changeset.apply_changes(socket.assigns.changeset)

  defp age_group_ids(socket) do
    socket |> data() |> Map.get(:age_groups, []) |> Enum.map(& &1[:dynamic_form_id])
  end

  @seeded %{
    "age_groups" => [
      %{"id" => "ag-1", "min" => "6", "max" => "12"},
      %{"id" => "ag-2", "min" => "12", "max" => "24"}
    ],
    "programs" => [%{"id" => "p-1", "name" => "Morning", "age_group_ids" => ["ag-1"]}]
  }

  describe "rendering" do
    test "choices come from the source's entries, valued by entry id" do
      html = @seeded |> then(&mount_component(instance(), &1)) |> render_form()

      assert html =~ ~s(value="ag-1")
      assert html =~ ~s(value="ag-2")
      assert html =~ "6 - 12"
      assert html =~ "12 - 24"
    end

    test "the stored selection renders checked" do
      html = @seeded |> then(&mount_component(instance(), &1)) |> render_form()

      assert html =~ ~s(name="dynamic_form[programs][0][age_group_ids][]" value="ag-1" checked)
      refute html =~ ~s(name="dynamic_form[programs][0][age_group_ids][]" value="ag-2" checked)
    end

    test "an entry missing an interpolated field is not offered as a choice" do
      # "6 - " is not a choice worth offering; the age group is still rendered
      # with its own hidden id, so assert on the consuming field only.
      html =
        %{@seeded | "age_groups" => [%{"id" => "ag-1", "min" => "6"}]}
        |> then(&mount_component(instance(), &1))
        |> render_form()

      refute html =~ ~s(name="dynamic_form[programs][0][age_group_ids][]" value="ag-1")
      refute html =~ "6 -"
    end

    test "an empty source renders no choices" do
      html =
        %{@seeded | "age_groups" => []}
        |> then(&mount_component(instance(), &1))
        |> render_form()

      refute html =~ ~s(name="dynamic_form[programs][0][age_group_ids][]" value="ag-)
    end

    test "no_choices_text replaces the control while the source is empty" do
      instance = instance(noChoicesText: "Add an age group above to assign it here.")

      empty = %{@seeded | "age_groups" => []}
      html = instance |> mount_component(empty) |> render_form()

      assert html =~ "Add an age group above to assign it here."
      # The label stays; the checkbox group does not render at all.
      assert html =~ "Age groups"
      refute html =~ ~s(name="dynamic_form[programs][0][age_group_ids][]")
    end

    test "no_choices_text gives way to the control once the source has entries" do
      instance = instance(noChoicesText: "Add an age group above to assign it here.")

      html = instance |> mount_component(@seeded) |> render_form()

      refute html =~ "Add an age group above"
      assert html =~ ~s(name="dynamic_form[programs][0][age_group_ids][]" value="ag-1")
    end

    test "choice_value names a different field" do
      html =
        instance(choiceValuesFromQuestion: "min")
        |> mount_component(@seeded)
        |> render_form()

      assert html =~ ~s(value="6")
      assert html =~ ~s(value="12")
    end

    test "choice_text can name a single field" do
      html =
        instance(choiceTextsFromQuestion: "min")
        |> mount_component(@seeded)
        |> render_form()

      assert html =~ ">6<" or html =~ "6</label>" or html =~ "6\n"
    end

    test "choice_text interpolates {panelIndex}" do
      html =
        instance(choiceTextsFromQuestion: "Group {panelIndex}")
        |> mount_component(@seeded)
        |> render_form()

      assert html =~ "Group 1"
      assert html =~ "Group 2"
    end
  end

  describe "stability" do
    test "renaming a source entry changes the label, not the stored value" do
      socket = mount_component(instance(), @seeded)
      [first, _] = age_group_ids(socket)

      socket =
        validate(socket, %{
          "age_groups" => %{
            "0" => %{"dynamic_form_id" => first, "min" => "3", "max" => "12"}
          },
          "programs" => %{
            "0" => %{"dynamic_form_id" => "p-1", "name" => "Morning", "age_group_ids" => [first]}
          }
        })

      assert [%{age_group_ids: [^first]}] = data(socket).programs
      assert render_form(socket) =~ "3 - 12"
    end
  end

  describe "pruning" do
    test "a reference to a deleted entry is dropped" do
      socket = mount_component(instance(), @seeded)

      # The user removes the first age group; the program still submits its id.
      socket =
        validate(socket, %{
          "age_groups" => %{"0" => %{"dynamic_form_id" => "ag-2", "min" => "12", "max" => "24"}},
          "programs" => %{
            "0" => %{"dynamic_form_id" => "p-1", "name" => "Morning", "age_group_ids" => ["ag-1"]}
          }
        })

      assert [%{age_group_ids: []}] = data(socket).programs
    end

    test "a still-valid reference survives" do
      socket = mount_component(instance(), @seeded)

      socket =
        validate(socket, %{
          "age_groups" => %{"0" => %{"dynamic_form_id" => "ag-1", "min" => "6", "max" => "12"}},
          "programs" => %{
            "0" => %{"dynamic_form_id" => "p-1", "name" => "Morning", "age_group_ids" => ["ag-1"]}
          }
        })

      assert [%{age_group_ids: ["ag-1"]}] = data(socket).programs
    end

    test "emptying the source clears the references" do
      # Deleting every age group is a user action, and keeping the ids would
      # hand the application a payload contradicting itself.
      socket = mount_component(instance(), @seeded)

      socket =
        validate(socket, %{
          "age_groups" => %{"__empty__" => ""},
          "programs" => %{
            "0" => %{"dynamic_form_id" => "p-1", "name" => "Morning", "age_group_ids" => ["ag-1"]}
          }
        })

      assert [%{age_group_ids: []}] = data(socket).programs
    end

    test "a source the submission omits keeps its references" do
      # A hidden section submits nothing, and the gap is filled from what the
      # form is already holding — entries and ids intact — so the reference
      # is still valid rather than looking like a deleted entry.
      socket = mount_component(instance(), @seeded)

      socket =
        validate(socket, %{
          "programs" => %{
            "0" => %{"dynamic_form_id" => "p-1", "name" => "Morning", "age_group_ids" => ["ag-1"]}
          }
        })

      assert [%{age_group_ids: ["ag-1"]}] = data(socket).programs
    end

    test "a source missing from the definition prunes nothing" do
      # Only reachable from a hand-edited data-mode definition; declarative
      # mode raises when choices_from names nothing.
      broken = instance(choicesFromQuestion: "does_not_exist")

      socket = mount_component(broken, @seeded)

      socket =
        validate(socket, %{
          "age_groups" => %{"__empty__" => ""},
          "programs" => %{
            "0" => %{"dynamic_form_id" => "p-1", "name" => "Morning", "age_group_ids" => ["ag-1"]}
          }
        })

      assert [%{age_group_ids: ["ag-1"]}] = data(socket).programs
    end
  end

  describe "other rendering paths" do
    test "render-only mode resolves once the parent seeds entry ids" do
      # The parent owns the changeset in render-only mode, so the seeding
      # RendererLive normally does is the parent's job — otherwise entries
      # have no dynamic_form_id and the default value resolves to nothing.
      instance = instance()
      questions = DynamicForm.Changeset.get_questions(instance.elements)

      form =
        @seeded
        |> DynamicForm.NestedForms.seed_entry_ids(questions)
        |> then(&DynamicForm.Changeset.create_changeset(instance, &1))
        |> Phoenix.Component.to_form(as: "dynamic_form")

      html =
        render_component(&DynamicForm.Renderer.render/1,
          instance: instance(),
          form: form,
          submit_text: "Submit",
          phx_submit: "submit",
          phx_change: "validate",
          target: nil,
          form_id: "tuition-form",
          disabled: false,
          hide_submit: false,
          gettext: DynamicForm.Gettext,
          uploads: %{},
          parent_id: nil
        )

      assert html =~ "6 - 12"
    end

    test "a source hidden by visible_if still supplies choices" do
      instance = instance()
      [age_groups, programs] = instance.elements
      hidden = %{instance | elements: [%{age_groups | visibleIf: "{never} = 'yes'"}, programs]}

      html = hidden |> mount_component(@seeded) |> render_form()

      # The source isn't rendered, but its values are still data.
      refute html =~ ~s(name="dynamic_form[age_groups][0][min]")
      assert html =~ "6 - 12"
    end

    test "labels update on every change, not on the debounce interval" do
      {:ok, socket} =
        RendererLive.update(
          %{
            id: "tuition",
            instance: instance(),
            data: @seeded,
            change_debounce_in_ms: 500,
            on_change: fn payload -> payload end
          },
          %Phoenix.LiveView.Socket{}
        )

      socket =
        validate(socket, %{
          "age_groups" => %{"0" => %{"dynamic_form_id" => "ag-1", "min" => "3", "max" => "12"}},
          "programs" => %{"0" => %{"dynamic_form_id" => "p-1", "age_group_ids" => ["ag-1"]}}
        })

      # Choices resolve from the changeset the built-in validations already
      # assigned, so the new label is there without waiting out the debounce.
      assert render_form(socket) =~ "3 - 12"
    end
  end

  describe "innermost-first scoping" do
    @deep %Instance{
      id: "org",
      elements: [
        %Instance.Question{
          name: "teams",
          type: "paneldynamic",
          title: "Teams",
          templateElements: [
            %Instance.Question{
              name: "members",
              type: "paneldynamic",
              title: "Members",
              templateElements: [%Instance.Question{name: "name", type: "text", title: "Name"}]
            },
            %Instance.Question{
              name: "lead",
              type: "dropdown",
              title: "Lead",
              choicesFromQuestion: "members",
              choiceTextsFromQuestion: "{name}"
            }
          ]
        }
      ]
    }

    test "a source inside the same entry wins over a form-level one" do
      html =
        @deep
        |> mount_component(%{
          "teams" => [
            %{"id" => "t-1", "members" => [%{"id" => "m-1", "name" => "Ada"}]},
            %{"id" => "t-2", "members" => [%{"id" => "m-2", "name" => "Grace"}]}
          ]
        })
        |> render_form()

      # Each team's lead dropdown lists only that team's members.
      [_, first_team] = String.split(html, ~s(name="dynamic_form[teams][0][lead]"), parts: 2)
      [first_team | _] = String.split(first_team, "</select>", parts: 2)

      assert first_team =~ "Ada"
      refute first_team =~ "Grace"
    end
  end

  describe "choice-typed sources" do
    defp choice_source_instance(overrides) do
      consuming =
        struct!(
          %Instance.Question{
            name: "primary",
            type: "dropdown",
            title: "Primary",
            choicesFromQuestion: "languages"
          },
          overrides
        )

      %Instance{
        id: "profile",
        elements: [
          %Instance.Question{
            name: "languages",
            type: "checkbox",
            title: "Languages",
            choices: [{"Elixir", "ex"}, {"Erlang", "erl"}, {"Rust", "rs"}]
          },
          consuming
        ]
      }
    end

    defp render_choices(overrides, data) do
      overrides |> choice_source_instance() |> mount_component(data) |> render_form()
    end

    test "all of the source's choices carry forward by default" do
      html = render_choices([], %{"languages" => ["ex"]})

      assert html =~ ~s(<option value="ex">Elixir</option>)
      assert html =~ ~s(<option value="erl">Erlang</option>)
      assert html =~ ~s(<option value="rs">Rust</option>)
    end

    test "selected mode carries only what the user picked there" do
      html =
        render_choices([choicesFromQuestionMode: "selected"], %{"languages" => ["ex", "rs"]})

      assert html =~ ~s(<option value="ex">Elixir</option>)
      assert html =~ ~s(<option value="rs">Rust</option>)
      refute html =~ ~s(<option value="erl">Erlang</option>)
    end

    test "unselected mode carries the rest" do
      html =
        render_choices([choicesFromQuestionMode: "unselected"], %{"languages" => ["ex", "rs"]})

      assert html =~ ~s(<option value="erl">Erlang</option>)
      refute html =~ ~s(<option value="ex">Elixir</option>)
    end

    test "a value the source no longer offers is pruned" do
      socket =
        [choicesFromQuestionMode: "selected"]
        |> choice_source_instance()
        |> mount_component(%{"languages" => ["ex", "rs"], "primary" => "rs"})

      assert data(socket).primary == "rs"

      # The user deselects Rust in the source.
      socket = validate(socket, %{"languages" => ["ex"], "primary" => "rs"})

      refute Map.has_key?(data(socket), :primary)
    end

    test "a value the definition no longer offers is pruned on load" do
      # Reopening a record whose stored value points at an option since
      # removed from the definition: the control can't display it either, so
      # it clears rather than round-tripping a value nothing offers.
      socket = mount_component(choice_source_instance([]), %{"primary" => "cobol"})

      refute Map.has_key?(data(socket), :primary)
    end

    test "an unknown mode raises" do
      socket =
        [choicesFromQuestionMode: "sometimes"]
        |> choice_source_instance()
        |> mount_component(%{"languages" => ["ex"]})

      assert_raise ArgumentError, ~r/choices_mode "sometimes"/, fn -> render_form(socket) end
    end
  end

  describe "declarative validation" do
    defp render_slots(field_overrides, nested_overrides \\ []) do
      assigns = %{field: field_overrides, nested: nested_overrides}

      render_component(
        fn assigns ->
          Phoenix.LiveView.TagEngine.component(
            &DynamicForm.form/1,
            [id: "f", field: assigns.field, nested: assigns.nested],
            {__ENV__.module, __ENV__.function, __ENV__.file, __ENV__.line}
          )
        end,
        assigns
      )
    end

    defp field(attrs), do: Map.new(attrs) |> Map.put(:__slot__, :field)
    defp nested(attrs), do: Map.new(attrs) |> Map.put(:__slot__, :nested)

    test "choices_from must name a nested form" do
      assert_raise ArgumentError, ~r/does not match a <:nested> form/, fn ->
        render_slots(
          [field(type: "checkbox", name: "picks", choices_from: "nope", choice_text: "{name}")],
          []
        )
      end
    end

    test "choices_from requires choice_text" do
      assert_raise ArgumentError, ~r/requires choice_text with choices_from/, fn ->
        render_slots(
          [
            field(type: "checkbox", name: "picks", choices_from: "items"),
            field(type: "text", name: "label", nested: "items")
          ],
          [nested(name: "items")]
        )
      end
    end

    test "choices_from only applies to choice fields" do
      assert_raise ArgumentError, ~r/only applies to choice fields/, fn ->
        render_slots(
          [
            field(type: "text", name: "picks", choices_from: "items", choice_text: "{label}"),
            field(type: "text", name: "label", nested: "items")
          ],
          [nested(name: "items")]
        )
      end
    end

    test "options and choices_from are mutually exclusive" do
      assert_raise ArgumentError, ~r/received both options and choices_from/, fn ->
        render_slots(
          [
            field(
              type: "checkbox",
              name: "picks",
              options: [{"A", "a"}],
              choices_from: "items",
              choice_text: "{label}"
            ),
            field(type: "text", name: "label", nested: "items")
          ],
          [nested(name: "items")]
        )
      end
    end

    test "choice_text without choices_from raises" do
      assert_raise ArgumentError, ~r/choice_text without choices_from/, fn ->
        render_slots([
          field(type: "checkbox", name: "picks", options: [{"A", "a"}], choice_text: "{x}")
        ])
      end
    end

    test "a source without ids requires choice_value" do
      assert_raise ArgumentError, ~r/generate_ids=\{false\}/, fn ->
        render_slots(
          [
            field(type: "checkbox", name: "picks", choices_from: "items", choice_text: "{label}"),
            field(type: "text", name: "label", nested: "items")
          ],
          [nested(name: "items", generate_ids: false)]
        )
      end
    end

    test "choice_text does not apply to a choice-typed source" do
      assert_raise ArgumentError, ~r/received choice_text, which applies to choices/, fn ->
        render_slots([
          field(type: "checkbox", name: "langs", options: [{"Elixir", "ex"}]),
          field(type: "dropdown", name: "primary", choices_from: "langs", choice_text: "{x}")
        ])
      end
    end

    test "choices_mode does not apply to a nested source" do
      assert_raise ArgumentError, ~r/received choices_mode, which applies/, fn ->
        render_slots(
          [
            field(
              type: "checkbox",
              name: "picks",
              choices_from: "items",
              choice_text: "{label}",
              choices_mode: "selected"
            ),
            field(type: "text", name: "label", nested: "items")
          ],
          [nested(name: "items")]
        )
      end
    end

    test "an unknown choices_mode raises" do
      assert_raise ArgumentError, ~r/expected one of: all, selected, unselected/, fn ->
        render_slots([
          field(type: "checkbox", name: "langs", options: [{"Elixir", "ex"}]),
          field(type: "dropdown", name: "primary", choices_from: "langs", choices_mode: "some")
        ])
      end
    end

    test "carry-forward cycles raise" do
      assert_raise ArgumentError, ~r/form a cycle/, fn ->
        render_slots([
          field(type: "checkbox", name: "a", choices_from: "b"),
          field(type: "checkbox", name: "b", choices_from: "a")
        ])
      end
    end

    test "a choice field with a slot body no longer needs options" do
      html =
        render_slots([
          field(
            type: "checkbox",
            name: "picks",
            inner_block: fn _changed, _field -> "BODY" end
          )
        ])

      assert html =~ "BODY"
    end
  end

  describe "JSON round trip" do
    test "the carry-forward fields survive encoding and decoding" do
      json = instance() |> Jason.encode!() |> Instance.decode!()

      [_age_groups, programs] = json.elements
      [_name, consuming] = programs.templateElements

      assert consuming.choicesFromQuestion == "age_groups"
      assert consuming.choiceTextsFromQuestion == "{min} - {max}"
    end
  end
end
