defmodule DemoWeb.NestedFormLive do
  @moduledoc """
  Demonstrates nested/repeating child forms via the SurveyJS `paneldynamic`
  question type: a user record with multiple addresses the user can add and
  remove, validated per entry with dynamic Ecto changesets.
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  @addresses_json """
  {
    "id": "nested-addresses-form",
    "title": "Contact with Addresses",
    "description": "A user record with a repeating list of addresses (SurveyJS paneldynamic)",
    "elements": [
      {"type": "text", "name": "name", "title": "Full name", "isRequired": true},
      {"type": "text", "name": "email", "title": "Email", "inputType": "email", "isRequired": true},
      {
        "type": "paneldynamic",
        "name": "addresses",
        "title": "Addresses",
        "description": "Add every address we should keep on file.",
        "templateTitle": "Address {panelIndex}",
        "templateElements": [
          {
            "type": "dropdown",
            "name": "kind",
            "title": "Type",
            "choices": ["Home", "Work", "Other"],
            "isRequired": true
          },
          {
            "type": "text",
            "name": "label",
            "title": "Label",
            "description": "Shown because Type is Other",
            "visibleIf": "{panel.kind} = 'Other'",
            "isRequired": true
          },
          {"type": "text", "name": "street", "title": "Street", "isRequired": true},
          {"type": "text", "name": "city", "title": "City", "isRequired": true},
          {
            "type": "text",
            "name": "zip",
            "title": "ZIP code",
            "validators": [
              {"type": "regex", "regex": "^\\\\d{5}$", "text": "Enter a 5-digit ZIP code"}
            ]
          }
        ],
        "panelCount": 1,
        "minPanelCount": 1,
        "maxPanelCount": 4,
        "addPanelText": "Add another address",
        "removePanelText": "Remove address",
        "confirmDelete": true,
        "confirmDeleteText": "Remove this address?",
        "keyName": "kind",
        "keyDuplicationError": "You already have an address of this type."
      }
    ]
  }
  """

  @edit_data %{
    "name" => "Ada Lovelace",
    "email" => "ada@example.com",
    "addresses" => [
      %{"kind" => "Home", "street" => "110 Main Street", "city" => "Portland", "zip" => "04101"},
      %{"kind" => "Work", "street" => "13 Dearborn", "city" => "Boston", "zip" => "02110"}
    ]
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:json, @addresses_json)
     |> assign(:json_pretty, @addresses_json |> Jason.decode!() |> Jason.encode!(pretty: true))
     |> assign(:edit_data, @edit_data)
     |> assign(:mode, :create)
     |> assign(:submitted_data, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Nested Forms (paneldynamic)</h1>
          <p class="mt-2 text-gray-600">
            A user record with a repeating list of child records — SurveyJS's
            <code class="text-sm">paneldynamic</code>
            question type. Each entry is validated with its own dynamic Ecto
            changeset, and the submitted data contains a nested list of maps:
            <code class="text-sm">
              %&lbrace;name: "...", addresses: [%&lbrace;street: "...", ...&rbrace;]&rbrace;
            </code>
          </p>
        </div>

        <div class="mb-6 flex flex-wrap gap-4">
          <button
            type="button"
            phx-click="switch_mode"
            phx-value-mode="create"
            class={"px-4 py-2 rounded-md #{if @mode == :create, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
          >
            Create mode (starts with one empty address)
          </button>
          <button
            type="button"
            phx-click="switch_mode"
            phx-value-mode="edit"
            class={"px-4 py-2 rounded-md #{if @mode == :edit, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
          >
            Edit mode (pre-populated with two addresses)
          </button>
          <button
            type="button"
            phx-click="switch_mode"
            phx-value-mode="slots"
            class={"px-4 py-2 rounded-md #{if @mode == :slots, do: "bg-indigo-600 text-white", else: "bg-gray-200 text-gray-700 hover:bg-gray-300"}"}
          >
            Declarative mode (&lt;:nested&gt; slots)
          </button>
        </div>

        <%= if @mode == :slots do %>
          <.definition
            title="Form Definition (HEEx slots)"
            subtitle="<:nested> declares the repeating form; fields join it with nested=; a group inside declares the same scope on both ends"
            code={slot_definition_source()}
          />
        <% else %>
          <.definition
            title="Form Definition (SurveyJS JSON)"
            subtitle="paneldynamic with templateElements, min/max panel counts, confirmDelete, keyName uniqueness, and a {panel.kind} conditional"
            code={@json_pretty}
          />
        <% end %>

        <div class="rounded-lg bg-gray-50 shadow-sm ring-1 ring-gray-900/5 p-6">
          <%= case @mode do %>
            <% :create -> %>
              <DynamicForm.form
                id="nested-create-form"
                json={@json}
                submit_text="Save Contact"
                validation_summary="detailed"
              />
            <% :edit -> %>
              <DynamicForm.form
                id="nested-edit-form"
                json={@json}
                data={@edit_data}
                submit_text="Update Contact"
                validation_summary="detailed"
              />
            <% :slots -> %>
              <DynamicForm.form
                id="nested-slot-form"
                components={DemoWeb.FormComponents}
                submit_text="Save Project"
              >
                <:field type="text" name="project" label="Project name" required />

                <:nested
                  name="milestones"
                  title="Milestones"
                  entry_title="Milestone {panelIndex}"
                  entries={1}
                  min_entries={1}
                  add_text="Add milestone"
                  remove_text="Remove milestone"
                />
                <:field nested="milestones" type="text" name="title" label="Title" required />
                <:field
                  :let={field}
                  nested="milestones"
                  type="text"
                  name="effort"
                  input_type="number"
                  label="Effort (days)"
                >
                  <input
                    type="range"
                    min="1"
                    max="30"
                    name={field.name}
                    id={field.id}
                    value={field.value || 5}
                    class="range range-sm"
                  />
                </:field>

                <:group name="schedule" title="Schedule" nested="milestones" />
                <:field
                  nested="milestones"
                  group="schedule"
                  type="dropdown"
                  name="quarter"
                  label="Quarter"
                  options={["Q1", "Q2", "Q3", "Q4"]}
                  required
                />
                <:field
                  nested="milestones"
                  group="schedule"
                  type="boolean"
                  name="committed"
                  label="Committed to customers?"
                />
              </DynamicForm.form>
          <% end %>
        </div>

        <%= if @submitted_data do %>
          <div class="mt-8 rounded-lg bg-green-50 p-6">
            <h3 class="text-lg font-semibold text-green-900 mb-4">✓ Submitted successfully!</h3>
            <div class="text-sm text-green-800">
              <p class="font-semibold mb-2">Payload data (note the nested list of address maps):</p>
              <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(@submitted_data, pretty: true) %></pre>
            </div>
          </div>
        <% end %>

        <div class="mt-8 rounded-lg bg-blue-50 p-6">
          <h3 class="text-lg font-semibold text-blue-900 mb-4">🪆 What to try</h3>
          <ul class="list-disc list-inside text-sm text-blue-800 space-y-1">
            <li>Click "Add another address" — up to <code>maxPanelCount: 4</code> entries</li>
            <li>
              Remove an address — <code>confirmDelete</code> asks first, and the last entry can't
              be removed (<code>minPanelCount: 1</code>)
            </li>
            <li>Pick "Other" as the type — a conditional "Label" field appears for that entry only
              (<code>visibleIf: &lbrace;panel.kind&rbrace; = 'Other'</code>)</li>
            <li>
              Give two addresses the same type — <code>keyName: "kind"</code> flags both entries
            </li>
            <li>Submit with a blank street — the error renders inline inside that entry</li>
            <li>Enter a non-numeric ZIP — per-entry regex validators apply</li>
            <li>
              Switch to declarative mode — the same feature defined with
              <code>&lt;:nested&gt;</code> HEEx slots, including a custom range control
              (<code>:let</code> slot body rendered once per entry) and a
              <code>&lt;:group&gt;</code> panel inside the nested form
            </li>
            <li>
              Notice the indigo entry cards in declarative mode — the components module
              (<code>DemoWeb.FormComponents</code>) defines <code>nested_entry/1</code>,
              replacing the default bordered container around each entry; create and edit
              mode show the built-in style
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp slot_definition_source do
    ~S"""
    <DynamicForm.form id="nested-slot-form" components={DemoWeb.FormComponents} submit_text="Save Project">
      <:field type="text" name="project" label="Project name" required />

      <:nested name="milestones" title="Milestones" entry_title="Milestone {panelIndex}"
               entries={1} min_entries={1} add_text="Add milestone" remove_text="Remove milestone" />
      <:field nested="milestones" type="text" name="title" label="Title" required />
      <:field :let={field} nested="milestones" type="text" name="effort"
              input_type="number" label="Effort (days)">
        <input type="range" min="1" max="30" name={field.name} id={field.id}
               value={field.value || 5} class="range range-sm" />
      </:field>

      <:group name="schedule" title="Schedule" nested="milestones" />
      <:field nested="milestones" group="schedule" type="dropdown" name="quarter"
              label="Quarter" options={["Q1", "Q2", "Q3", "Q4"]} required />
      <:field nested="milestones" group="schedule" type="boolean" name="committed"
              label="Committed to customers?" />
    </DynamicForm.form>
    """
  end

  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(:mode, String.to_existing_atom(mode))
     |> assign(:submitted_data, nil)}
  end

  @impl true
  def handle_info({:dynamic_form, :success, %DynamicForm.Payload{data: data}}, socket) do
    {:noreply,
     socket
     |> assign(:submitted_data, data)
     |> put_flash(:info, "Contact saved!")}
  end
end
