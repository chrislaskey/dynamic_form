defmodule DynamicForm do
  @moduledoc """
  DynamicForm - A Phoenix LiveView library for creating dynamic forms with full
  server-side validation using changesets. Also supports building forms
  through a WYSIWYG interface.

  This library enables users to build forms dynamically through a visual interface,
  then render those forms using standard Phoenix LiveView patterns with robust
  validation and submission handling.

  ## External Submit Buttons

  DynamicForm supports placing submit buttons outside of the form element using
  the HTML `form` attribute. This is useful for:

  - Placing submit buttons in modal footers
  - Creating sticky footers with submit buttons
  - Multi-step forms with navigation controls
  - Complex layouts where the submit button needs to be separate

  ### Usage with RendererLive (Recommended)

  When using `DynamicForm.RendererLive` (LiveComponent):

  1. Set `hide_submit={true}` on your LiveComponent
  2. Use `DynamicForm.submit_button/1` with the form ID `"\#{component_id}-form"`

  Example:

      # External submit button
      <DynamicForm.submit_button form="contact-form-form">
        Submit
      </DynamicForm.submit_button>

      # LiveComponent (id "contact-form" generates form ID "contact-form-form")
      <.live_component
        module={DynamicForm.RendererLive}
        id="contact-form"
        instance={@form_instance}
        hide_submit={true}
      />

  ### Usage with Renderer (Functional Component)

  When using `DynamicForm.Renderer.render/1`:

  1. Set `hide_submit={true}` and provide a custom `form_id`
  2. Use `DynamicForm.submit_button/1` with that `form_id`

  Example:

      # External submit button
      <DynamicForm.submit_button form="my-form">
        Save
      </DynamicForm.submit_button>

      # Renderer with custom form_id
      <DynamicForm.Renderer.render
        instance={@form_instance}
        form={@form}
        form_id="my-form"
        hide_submit={true}
        phx_submit="submit"
        phx_change="validate"
      />

  See `DynamicForm.RendererLive.submit_button/1` for more details.

  ## Declarative Forms

  `DynamicForm.form/1` is the unified entry point for rendering forms. It
  accepts a prebuilt instance, a SurveyJS-compatible JSON string, or
  `<:field>` slots (declarative mode) — exactly one of the three:

      <%!-- Data mode: Instance struct or map --%>
      <DynamicForm.form id="contact-form" instance={@form_instance} />

      <%!-- Data mode: SurveyJS-compatible JSON string --%>
      <DynamicForm.form id="contact-form" json={@json} />

      <%!-- Declarative mode --%>
      <DynamicForm.form id="contact-form" title="Contact Form">
        <:field type="text" input_type="email" name="email" label="Email Address" required />
        <:field type="dropdown" name="subject" label="Subject"
                options={[{"Support", "support"}, {"Sales", "sales"}]} />
        <:field type="comment" name="details" label="Details"
                visible_if="{subject} = 'support'" />
      </DynamicForm.form>

  See `form/1` for the full attribute and slot reference.
  """

  use Phoenix.Component
  # This module defines its own form/1 component, shadowing Phoenix.Component's
  import Phoenix.Component, except: [form: 1]

  alias DynamicForm.{Changeset, Instance, Renderer}

  defdelegate submit_button(assigns), to: DynamicForm.RendererLive

  @doc """
  The whole form's current values, for reading inside a `<:field>` slot body.

  Takes the `Phoenix.HTML.FormField` a custom control receives, or the
  `Phoenix.HTML.Form` a `type="custom"` element receives, and returns the
  applied changeset data — the same map a `:change` message delivers as
  `payload.data`, with nested entries as lists of maps:

      %{name: "Ada", addresses: [%{street: "110 Main St", city: "Portland"}]}

  The map is always form-level, even inside a nested entry, so a control in
  one nested form can read another's entries:

      <:field :let={field} nested="rooms" type="checkbox" name="teachers">
        <%= for teacher <- DynamicForm.form_data(field)[:staff] || [] do %>
          <label>
            <input type="checkbox" name={"\#{field.name}[]"} value={teacher[:id]} />
            {teacher[:name]}
          </label>
        <% end %>
      </:field>

  Values the user hasn't entered are absent rather than `nil`, as with any
  `Ecto.Changeset.apply_changes/1` result — default to `[]` or `%{}` when
  reading. In [render-only mode](usage.md#render-only-mode) the parent owns
  the changeset, so the shape is whatever that changeset applies to.

  Raises when given a form DynamicForm didn't render.
  """
  @spec form_data(Phoenix.HTML.FormField.t() | Phoenix.HTML.Form.t()) :: map()
  def form_data(%Phoenix.HTML.FormField{form: form}), do: form_data(form)

  def form_data(%Phoenix.HTML.Form{options: options}) do
    case Keyword.fetch(options, :form_data) do
      {:ok, data} ->
        data

      :error ->
        raise ArgumentError,
              "DynamicForm.form_data/1 works on the field or form a <:field> slot body " <>
                "receives, and this form was not rendered by DynamicForm"
    end
  end

  @doc """
  Renders a dynamic form from an instance, a SurveyJS-compatible JSON string,
  or `<:field>` slots (declarative mode).

  Wraps `DynamicForm.RendererLive`, which manages form state, validation, and
  submission. Exactly one of the `instance` attribute, the `json` attribute,
  or `<:field>` slots must be provided.

  ## Lifecycle callbacks

  Two optional validation hooks mirror the form's `phx-change`/`phx-submit`
  events. Each is a 1-arity function receiving a `DynamicForm.Payload` and
  returning it, transformed or untouched. Reject a submission with
  `DynamicForm.Payload.add_error/4`; side effects belong in the parent's
  `handle_info/2`:

    * `on_change` — runs after the built-in validations on every change (and
      during the submit validation pass). Keep it cheap — it runs per
      keystroke, unless `change_debounce_in_ms` is set.
    * `on_submit` — runs on **every** submit, valid or not, so it can batch
      expensive checks with the built-in errors into one complete error list.

      <DynamicForm.form id="contact-form" on_submit={&Contacts.verify/1}>
        <:field type="text" name="email" label="Email" required format="email" />
      </DynamicForm.form>

  `change_debounce_in_ms` waits for that many milliseconds of quiet before
  running the change work, so a callback too expensive for a keystroke runs
  once the user pauses. The built-in validations still render on every
  change, and submitting always runs the callback inline:

      <DynamicForm.form id="signup" on_change={&Accounts.check_availability/1}
                        change_debounce_in_ms={300}>
        <:field type="text" name="username" label="Username" required />
      </DynamicForm.form>

  ## Messages

  The parent LiveView is messaged as `{:dynamic_form, event, payload}`.
  `send_message_on` picks the events — any of `[:success, :change,
  :submit]`, defaulting to `[:success]`:

      <DynamicForm.form id="signup" send_message_on={[:success, :change]}>

      def handle_info({:dynamic_form, :change, payload}, socket) do
        {:noreply, assign(socket, :preview, payload.data)}
      end

  `:change` and `:submit` payloads are routinely invalid — check
  `DynamicForm.Payload.valid?/1` before acting on them. Pair `:change` with
  `change_debounce_in_ms` to keep a message (and a parent re-render) off
  every keystroke. Define `on_success` — a 1-arity function receiving the
  payload — to replace the `:success` message with custom behavior. See
  `DynamicForm.RendererLive` and `DynamicForm.Payload` for the full
  contracts.

  ## Declarative mode

  `<:field>` entries convert to a `DynamicForm.Instance` in template order
  (see `DynamicForm.Instance.FromSlots`). Question types collect input;
  `html`, `image`, and `custom` render static or custom content:

      <DynamicForm.form id="signup">
        <:field type="html" name="intro" html="<h2>Sign up</h2>" />
        <:field type="text" name="email" label="Email" format="email" required />
        <:field type="rating" name="score" label="Score" rate_min={1} rate_max={10} />
      </DynamicForm.form>

  ### Groups (panels)

  Fields sharing a `group` attribute are collected into a panel declared by a
  `<:group>` entry. The panel renders at the position of its first member:

      <:group name="address" title="Shipping Address" visible_if="{ship} = true" />
      <:field group="address" type="text" name="street" label="Street" />
      <:field group="address" type="text" name="city" label="City" />

  ### Nested forms (repeating entries)

  A `<:nested>` entry declares a repeating child form; fields join it with
  `nested="name"` and the submitted value becomes a list of maps, each entry
  validated with its own changeset. `nested` declares a field's data scope
  and `group` its visual grouping — they combine. See the Nested Forms guide:

      <:nested name="addresses" title="Addresses" min_entries={1}
               add_text="Add another address" />
      <:field nested="addresses" type="text" name="street" label="Street" required />
      <:field nested="addresses" type="text" name="city" label="City" required />

  ### Custom markup (slot bodies)

  A `<:field>` body customizes rendering. Three tiers:

      <%!-- Content block: body instead of the html attribute --%>
      <:field type="html" name="intro">
        <h2>Welcome, {@current_user.name}</h2>
      </:field>

      <%!-- Custom control: body receives the Phoenix.HTML.FormField; the
           library still renders the label and errors, and the changeset
           still validates the field --%>
      <:field type="text" input_type="number" name="amount" label="Amount" :let={field}>
        <input type="range" min="0" max="100" name={field.name} id={field.id}
               value={field.value || 0} />
      </:field>

      <%!-- Fully custom element: body receives the Phoenix form --%>
      <:field type="custom" name="summary" :let={form}>
        <p>Total: {form[:amount].value}</p>
      </:field>

  A body reads its own scope through the value it receives, and the whole
  form — including other nested forms' entries — through
  `DynamicForm.form_data/1`.

  Slot bodies are in-memory only: instances containing them JSON-encode
  without the bodies, and such forms cannot round-trip through the WYSIWYG
  builder.

  ## Render-only mode

  For full control over the form lifecycle, `render_only` renders the markup
  only — no LiveComponent, no managed state. Events are emitted without a
  `phx-target`, so they land in the parent LiveView's `handle_event/3`
  exactly like an idiomatic `<form phx-change="validate" phx-submit="submit">`,
  and the parent owns the form state, passing its `Phoenix.HTML.Form` in:

      <DynamicForm.form id="signup" render_only form={@form}>
        <:field type="text" name="name" label="Name" required />
        <:field type="text" name="email" input_type="email" label="Email" required />
      </DynamicForm.form>

      def handle_event("validate", %{"signup" => params}, socket) do
        changeset = Accounts.change_user(%User{}, params) |> Map.put(:action, :validate)
        {:noreply, assign(socket, form: to_form(changeset, as: "signup"))}
      end

      def handle_event("submit", %{"signup" => params}, socket) do
        # entirely yours
      end

  The definition drives presentation — markup, labels, errors, conditional
  visibility — while the parent's changeset drives the data. Override the
  event names with `phx_change` and `phx_submit`.

  Lifecycle attributes (`on_change`, `change_debounce_in_ms`, `on_submit`,
  `on_success`, `send_message_on`, `data`, `form_name`,
  `validation_summary`) have no meaning without the managed lifecycle and
  raise. File upload questions require the stateful component and raise.
  """
  attr(:id, :string,
    required: true,
    doc: "Component ID; also the instance id in declarative mode"
  )

  attr(:instance, :any,
    default: nil,
    doc:
      "Data mode: an Instance struct, JSON string, or map. Mutually exclusive with json and <:field> slots."
  )

  attr(:json, :string,
    default: nil,
    doc:
      "Data mode: a SurveyJS-compatible JSON string, decoded with Instance.decode!/1. " <>
        "Mutually exclusive with instance and <:field> slots."
  )

  attr(:title, :string, default: nil, doc: "Instance title (declarative mode)")
  attr(:description, :string, default: nil, doc: "Instance description (declarative mode)")

  attr(:on_change, :any,
    default: nil,
    doc:
      "1-arity function (DynamicForm.Payload) -> DynamicForm.Payload, run after " <>
        "built-in validations on every change and during the submit validation pass"
  )

  attr(:change_debounce_in_ms, :integer,
    default: nil,
    doc:
      "Milliseconds of quiet before a change runs on_change and sends its " <>
        ":change message; without it both happen on every change"
  )

  attr(:on_submit, :any,
    default: nil,
    doc:
      "1-arity function (DynamicForm.Payload) -> DynamicForm.Payload, run on " <>
        "every submit — valid or not"
  )

  attr(:data, :map,
    default: %{},
    doc:
      "Initial form data for edit mode — existing record values (a payload's " <>
        "data round-trips directly)"
  )

  attr(:form_name, :string, default: "dynamic_form", doc: "Form namespace for submitted params")
  attr(:submit_text, :string, default: "Submit", doc: "Submit button text")

  attr(:on_success, :any,
    default: nil,
    doc:
      "1-arity function (DynamicForm.Payload), run on every valid submission " <>
        "instead of sending the {:dynamic_form, :success, payload} message"
  )

  attr(:send_message_on, :list,
    default: nil,
    doc:
      "Lifecycle events that message the parent LiveView: any of " <>
        "[:success, :change, :submit] (default: [:success])"
  )

  attr(:hide_submit, :boolean, default: false, doc: "Hide the submit button")
  attr(:gettext, :atom, default: DynamicForm.Gettext, doc: "Gettext backend for translations")

  attr(:components, :atom,
    default: nil,
    doc:
      "Custom components module (e.g. the app's Phoenix-generated CoreComponents); " <>
        "functions it exports override the built-ins per function. Falls back to the " <>
        ":dynamic_form, :components config — see DynamicForm.Components"
  )

  attr(:custom_field_types, :map,
    default: nil,
    doc:
      "Custom field types map (type name => Ecto type), merged over the " <>
        ":dynamic_form, :custom_field_types config; rendering dispatches to the " <>
        "components module's input/1 — see DynamicForm.FieldTypes"
  )

  attr(:validation_summary, :string,
    default: nil,
    doc: "Display validation errors at the top of the form: nil, \"simple\", or \"detailed\""
  )

  attr(:render_only, :boolean,
    default: false,
    doc:
      "Render the form markup only: events go to the parent LiveView's " <>
        "handle_event/3 and the parent owns the form state. Requires form."
  )

  attr(:form, :any,
    default: nil,
    doc: "Render-only mode: the parent-owned Phoenix.HTML.Form to render against"
  )

  attr(:phx_change, :string,
    default: nil,
    doc: ~s|Render-only mode: change event name (default "validate")|
  )

  attr(:phx_submit, :string,
    default: nil,
    doc: ~s|Render-only mode: submit event name (default "submit")|
  )

  slot :field, doc: "Form elements in render order (declarative mode)" do
    attr(:type, :string,
      required: true,
      doc:
        "Question or element type: text, comment, dropdown, radiogroup, checkbox, " <>
          "boolean, rating, tagbox, file, html, image, custom, or a registered " <>
          "custom field type (validated at runtime)"
    )

    attr(:name, :string,
      doc: "Field name (required for question types; auto-generated for html/image/custom)"
    )

    attr(:label, :string, doc: "Question title / image alt text")
    attr(:placeholder, :string)
    attr(:description, :string, doc: "Help text shown below the input")
    attr(:input_type, :string, doc: ~s|HTML input type for type="text" (email, number, ...)|)
    attr(:default, :any, doc: "Default value seeded into the form params")

    attr(:options, :list,
      doc:
        ~s|Choices for dropdown/radiogroup/checkbox/tagbox: [{"Label", "value"}, ...] or ["value", ...]|
    )

    attr(:required, :boolean)
    attr(:required_if, :string, doc: "SurveyJS expression, e.g. \"{other} notempty\"")
    attr(:visible_if, :string, doc: "SurveyJS expression, e.g. \"{subject} = 'support'\"")
    attr(:enable_if, :string, doc: "SurveyJS expression; disabled when false")
    attr(:read_only, :boolean)
    attr(:group, :string, doc: "Collect this field into the <:group> panel with this name")

    attr(:nested, :string,
      doc:
        "Data scope: collect this field into the <:nested> form with this name. " <>
          "Combines with group — see the Nested Forms guide"
    )

    attr(:rate_min, :integer, doc: ~s|type="rating" only|)
    attr(:rate_max, :integer, doc: ~s|type="rating" only|)
    attr(:rate_step, :integer, doc: ~s|type="rating" only|)
    attr(:min_length, :integer, doc: "Text length validation")
    attr(:max_length, :integer, doc: "Text length validation")
    attr(:min, :any, doc: "Numeric range validation")
    attr(:max, :any, doc: "Numeric range validation")
    attr(:pattern, :string, doc: "Regex validation")
    attr(:format, :string, doc: ~s|Format validation; supported: "email"|)
    attr(:validators, :list, doc: "Escape hatch: Instance.Validator structs or atom-keyed maps")
    attr(:html, :string, doc: ~s|Raw HTML content for type="html" (alternative to a slot body)|)
    attr(:src, :string, doc: ~s|type="image" only: image URL|)
    attr(:width, :string, doc: ~s|type="image" only, e.g. "300px"|)
    attr(:height, :string, doc: ~s|type="image" only|)
    attr(:fit, :string, doc: ~s|type="image" only: CSS object-fit value|)
    attr(:metadata, :map, doc: "Metadata map (file upload config, radiogroup style, ...)")
  end

  slot :group, doc: "Panel declarations referenced by <:field group=\"...\"> entries" do
    attr(:name, :string, required: true)
    attr(:title, :string)
    attr(:visible_if, :string)
    attr(:enable_if, :string)

    attr(:nested, :string,
      doc:
        "Data scope this group lives in. A group inside a nested form declares it here, " <>
          "and every member field must declare the identical nested scope"
    )
  end

  slot :nested,
    doc:
      "Nested (repeating) form declarations referenced by <:field nested=\"...\"> entries — " <>
        "the declarative counterpart to the SurveyJS paneldynamic question" do
    attr(:name, :string, required: true, doc: "Data key: the value is a list of entry maps")
    attr(:title, :string)
    attr(:description, :string, doc: "Help text shown below the title")

    attr(:entry_title, :string,
      doc: ~s|Per-entry heading; "{panelIndex}" interpolates the 1-based entry number|
    )

    attr(:entries, :integer,
      doc: "Entries seeded on a fresh form (default 0, raised to min_entries)"
    )

    attr(:min_entries, :integer, doc: "Entries cannot be removed below this; validated on submit")
    attr(:max_entries, :integer, doc: "The add button hides at this count; validated on submit")
    attr(:add_text, :string, doc: ~s|Add button label (default "Add new")|)
    attr(:remove_text, :string, doc: ~s|Remove button label (default "Remove")|)
    attr(:no_entries_text, :string, doc: "Shown when the form has zero entries")
    attr(:confirm_delete, :boolean, doc: "Ask for confirmation before removing an entry")
    attr(:confirm_text, :string, doc: "Confirmation dialog text")
    attr(:key, :string, doc: "Member field whose value must be unique across entries")
    attr(:key_error, :string, doc: "Error message for key duplicates")

    attr(:generate_ids, :boolean,
      doc:
        "Seed each entry with a stable dynamic_form_id, copied from the entry's id " <>
          "when the data came from a stored record (default true)"
    )

    attr(:default, :list, doc: "Initial value: a list of entry maps (edit-mode style seeding)")
    attr(:default_entry, :map, doc: "Values seeded into each newly added entry")
    attr(:required, :boolean, doc: "At least one entry is required")
    attr(:visible_if, :string)
    attr(:enable_if, :string)

    attr(:nested, :string, doc: "Place this nested form inside another <:nested> form's template")

    attr(:group, :string, doc: "Place this nested form inside a <:group> panel")
  end

  def form(%{render_only: true} = assigns) do
    assigns = assign(assigns, :resolved_instance, resolve_instance(assigns))
    validate_render_only!(assigns)

    assigns =
      assigns
      |> assign(:phx_change, assigns.phx_change || "validate")
      |> assign(:phx_submit, assigns.phx_submit || "submit")

    ~H"""
    <Renderer.render
      instance={@resolved_instance}
      form={@form}
      phx_change={@phx_change}
      phx_submit={@phx_submit}
      form_id={"#{@id}-form"}
      submit_text={@submit_text}
      hide_submit={@hide_submit}
      gettext={@gettext}
      components={@components}
      custom_field_types={@custom_field_types}
    />
    """
  end

  def form(assigns) do
    assigns = assign(assigns, :resolved_instance, resolve_instance(assigns))
    validate_stateful!(assigns)

    ~H"""
    <.live_component
      module={DynamicForm.RendererLive}
      id={@id}
      instance={@resolved_instance}
      on_change={@on_change}
      change_debounce_in_ms={@change_debounce_in_ms}
      on_submit={@on_submit}
      on_success={@on_success}
      send_message_on={@send_message_on}
      data={@data}
      form_name={@form_name}
      submit_text={@submit_text}
      hide_submit={@hide_submit}
      gettext={@gettext}
      validation_summary={@validation_summary}
      components={@components}
      custom_field_types={@custom_field_types}
    />
    """
  end

  # Render-only mode renders markup against a parent-owned form — attributes
  # that configure the managed lifecycle have no meaning there and raise.
  defp validate_render_only!(assigns) do
    unless match?(%Phoenix.HTML.Form{}, assigns.form) do
      raise ArgumentError,
            "DynamicForm.form id=#{inspect(assigns.id)} render_only requires the form " <>
              "attribute with the parent-owned Phoenix.HTML.Form, got: #{inspect(assigns.form)}"
    end

    invalid =
      [
        on_change: assigns.on_change,
        change_debounce_in_ms: assigns.change_debounce_in_ms,
        on_submit: assigns.on_submit,
        on_success: assigns.on_success,
        send_message_on: assigns.send_message_on,
        validation_summary: assigns.validation_summary
      ]
      |> Enum.reject(fn {_attr, value} -> is_nil(value) end)
      |> then(&if assigns.data == %{}, do: &1, else: [{:data, assigns.data} | &1])
      |> then(
        &if assigns.form_name == "dynamic_form",
          do: &1,
          else: [{:form_name, assigns.form_name} | &1]
      )
      |> Enum.map(fn {attr, _value} -> attr end)

    if invalid != [] do
      raise ArgumentError,
            "DynamicForm.form id=#{inspect(assigns.id)} render_only renders markup only — " <>
              "the parent LiveView owns the form lifecycle. " <>
              "Remove: #{Enum.join(invalid, ", ")}"
    end

    file_questions =
      assigns.resolved_instance.elements
      |> Changeset.get_questions()
      |> Enum.filter(&(&1.type == "file"))

    if file_questions != [] do
      raise ArgumentError,
            "DynamicForm.form id=#{inspect(assigns.id)} render_only does not support " <>
              "file upload questions (#{Enum.map_join(file_questions, ", ", & &1.name)}) — " <>
              "uploads require the stateful component"
    end
  end

  # The stateful component owns the form and its events — the render-only
  # attributes conflict with that and raise.
  defp validate_stateful!(assigns) do
    invalid =
      [form: assigns.form, phx_change: assigns.phx_change, phx_submit: assigns.phx_submit]
      |> Enum.reject(fn {_attr, value} -> is_nil(value) end)
      |> Enum.map(fn {attr, _value} -> attr end)

    if invalid != [] do
      raise ArgumentError,
            "DynamicForm.form id=#{inspect(assigns.id)} received " <>
              "#{Enum.join(invalid, ", ")} without render_only — the component owns the " <>
              "form and its events unless render_only is set"
    end
  end

  # The form definition comes from exactly one of three modes: the instance
  # attribute, the json attribute, or <:field>/<:group> slots.
  defp resolve_instance(assigns) do
    case definition_modes(assigns) do
      [:instance] ->
        assigns.instance

      [:json] ->
        decode_json!(assigns)

      [:slots] ->
        Instance.FromSlots.convert!(assigns)

      [] ->
        raise ArgumentError,
              "DynamicForm.form id=#{inspect(assigns.id)} requires a form definition: " <>
                "an instance attribute, a json attribute, or <:field> slots"

      modes ->
        raise ArgumentError,
              "DynamicForm.form id=#{inspect(assigns.id)} received multiple form " <>
                "definitions (#{Enum.map_join(modes, " and ", &inspect/1)}) — provide exactly one"
    end
  end

  defp definition_modes(assigns) do
    [
      instance: not is_nil(assigns.instance),
      json: not is_nil(assigns.json),
      slots: assigns.field != [] or assigns.group != [] or assigns[:nested] not in [nil, []]
    ]
    |> Enum.filter(fn {_mode, present?} -> present? end)
    |> Enum.map(fn {mode, _present?} -> mode end)
  end

  defp decode_json!(%{json: json}) when is_binary(json), do: Instance.decode!(json)

  defp decode_json!(%{json: other} = assigns) do
    raise ArgumentError,
          "DynamicForm.form id=#{inspect(assigns.id)} json attribute must be a JSON " <>
            "string — for maps or Instance structs use the instance attribute. " <>
            "Got: #{inspect(other)}"
  end
end
