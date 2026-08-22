defmodule DynamicForm do
  @moduledoc """
  DynamicForm - A Phoenix LiveView library for creating dynamic forms with full
  server-side validation using changesets. Also supports building forms
  through a WYSIWYG interface.

  This library enables users to build forms dynamically through a visual interface,
  then render those forms using standard Phoenix LiveView patterns with robust
  validation and submission handling.

  ## Declarative Forms

  `DynamicForm.form/1` is the unified entry point for rendering forms. It
  accepts a declarative definition using `<:field>` slots, a
  SurveyJS-compatible JSON string, or an instance using Elixir data structures:

      <%!-- Declarative --%>
      <DynamicForm.form id="contact-form">
        <:field type="text" input_type="email" name="email" label="Email" required />
      </DynamicForm.form>

      <%!-- Data: SurveyJS-compatible JSON string --%>
      <DynamicForm.form id="contact-form" json={@json} />

      <%!-- Data: Instance struct or map --%>
      <DynamicForm.form id="contact-form" instance={@form_instance} />

  """

  use Phoenix.Component

  import Phoenix.Component, except: [form: 1]

  defdelegate submit_button(assigns), to: DynamicForm.Renderer.LiveComponent

  @doc """
  Renders a dynamic form from an instance, a SurveyJS-compatible JSON string,
  or `<:field>` slots (declarative mode).

  Wraps `DynamicForm.Renderer.LiveComponent`, which manages form state, validation, and
  submission. Exactly one of the `instance` attribute, the `json` attribute,
  or `<:field>` slots must be provided.

  ## Messages

  When a user changes a value or submits the form, the library validates the
  changes with it's own internal state and then sends messages to the parent
  LiveView or LiveComponent.

  The messages are in the format of `{:dynamic_form, event, payload}`.

  By default, the form will only send the `:success` event. Which only occurs
  when the user submits a form with no validation errors.

      <DynamicForm.form id="signup">

      def handle_info({:dynamic_form, :success, payload}, socket) do
        {:ok, record} = Context.create(payload.data)

        {:noreply, push_navigate(socket, to: ~p"/success")}
      end

  It is also possible to receive `:change` and `:submit` events too. The
  `send_messages_on` attribute can be used to define a list of events to
  receive:

      <DynamicForm.form id="signup" send_message_on={[:change, :success]}>

      def handle_info({:dynamic_form, :change, payload}, socket) do
        # ...
      end

      def handle_info({:dynamic_form, :success, payload}, socket) do
        # ...
      end

  When using `:change` and `:submit` the form data may be invalid. The
  `DynamicForm.Payload.valid?/1` helper is available to check valid state.

  Note: The `:change` event can also be paired with the `change_debounce_in_ms`
  to add a debounce filter to the change events sent. Without it, every change
  will send a message.

  See `DynamicForm.Renderer.LiveComponent` and `DynamicForm.Payload` for the full details. 

  ## Lifecycle callbacks

  Receiving messages is the standard way to work with data coming from
  DynamicForm. Most form flows do not require any additional changes
  to the form's lifecycle - the library defaults are sufficient.

  For some more complex form flows, it's useful to be able to hook into
  the internal lifecycle events that happen within the library.

  In those cases, there are two optional validation hooks mirror the form's
  `phx-change`/`phx-submit` events. Each is a 1-arity function receiving a
  `DynamicForm.Payload` and returning it, transformed or untouched. Reject a
  submission with `DynamicForm.Payload.add_error/4`; side effects belong in the
  parent's `handle_info/2`:

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

      <DynamicForm.form id="signup" on_change={&Accounts.check_availability/1} change_debounce_in_ms={300}>
        <:field type="text" name="username" label="Username" required />
      </DynamicForm.form>

  ## Declarative mode

  `<:field>` entries convert to a `DynamicForm.Instance` in template order
  (see `DynamicForm.Parser.Declarative`). Question types collect input;
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

  The DynamicForm library can also be used as a pure renderer. In this setup,
  the form is rendered as a functional component on the page. The standard
  `phx-change` and `phx-submit` event handlers get sent directly to the parent
  LiveView as-is. That means no LiveComponent or managed state. In other words,
  no validation or type casting, no changeset or error management.

  To enable this mode, add the `render_only` attribute.

  Events are emitted without a `phx-target`, so they land in the parent
  LiveView's `handle_event/3` exactly like an idiomatic `<form
  phx-change="validate" phx-submit="submit">`, and the parent owns the form
  state, passing its `Phoenix.HTML.Form` in:

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

  Note: Lifecycle attributes (`on_change`, `change_debounce_in_ms`, `on_submit`,
  `on_success`, `send_message_on`, `data`, `form_name`,
  `validation_summary`) have no meaning in the `render_only` mode and
  will raise an exception. File upload questions require the stateful component
  and also raise.
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

    attr(:label, :any,
      doc:
        "Question title / image alt text. Blank (nil, false, or \"\") renders no " <>
          "label, and no required marker with it; omitting it falls back to the name"
    )

    attr(:placeholder, :string)
    attr(:description, :string, doc: "Help text shown below the input")
    attr(:input_type, :string, doc: ~s|HTML input type for type="text" (email, number, ...)|)
    attr(:default, :any, doc: "Default value seeded into the form params")

    attr(:options, :list,
      doc:
        ~s|Choices for dropdown/radiogroup/checkbox/tagbox: [{"Label", "value"}, ...] or ["value", ...]|
    )

    attr(:choices_from, :string,
      doc:
        "Carry forward: build this field's choices from another question's values, " <>
          "typically a <:nested> form. Mutually exclusive with options"
    )

    attr(:choice_value, :string,
      doc:
        "Carry forward: the source field supplying each choice's value " <>
          "(default: the entry's dynamic_form_id)"
    )

    attr(:choice_text, :string,
      doc:
        ~s|Carry forward: the source field supplying each choice's label, or a | <>
          ~s|template interpolating them — "{min} - {max}", "{panelIndex}"|
    )

    attr(:choices_mode, :string,
      doc:
        ~s|Carry forward from another choice field: "all" (default), "selected", | <>
          ~s|or "unselected"|
    )

    attr(:no_choices_text, :string,
      doc:
        "Shown in place of the control when the field has no choices yet — " <>
          "typically a carried-forward source with no entries"
    )

    attr(:required, :boolean)

    attr(:required_label, :any,
      doc:
        ~s|Mark shown beside a required field's label (default "*"). Blank (nil, | <>
          ~s|false, or "") shows none while the field stays required|
    )

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
    attr(:title, :any, doc: ~s|Panel heading; blank (nil, false, or "") renders none|)

    attr(:type, :string,
      doc:
        ~s|Layout: "horizontal" (default, members share a row and wrap) or | <>
          ~s|"vertical", or a type your components module defines|
    )

    attr(:visible_if, :string)
    attr(:enable_if, :string)

    attr(:group, :string,
      doc:
        "Place this group inside another <:group> panel. It renders at the position of " <>
          "its own first member field, and must declare the same nested scope as its parent"
    )

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

    attr(:title, :any,
      doc:
        ~s|Section heading; blank (nil, false, or "") renders none, while omitting | <>
          ~s|it falls back to the capitalized name|
    )

    attr(:description, :string, doc: "Help text shown below the title")

    attr(:entry_title, :any,
      doc:
        ~s|Per-entry heading; "{panelIndex}" interpolates the 1-based entry number. | <>
          ~s|Blank renders none|
    )

    attr(:entries, :integer,
      doc: "Entries seeded on a fresh form (default 0, raised to min_entries)"
    )

    attr(:min_entries, :integer, doc: "Entries cannot be removed below this; validated on submit")
    attr(:max_entries, :integer, doc: "The add button hides at this count; validated on submit")
    attr(:add_text, :string, doc: ~s|Add button label (default "Add new")|)

    attr(:remove_text, :string,
      doc:
        ~s|Remove button label (default "Remove"). The control is an icon, so | <>
          ~s|this becomes its tooltip and screen-reader name|
    )

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

    attr(:required_label, :any,
      doc: ~s|Mark beside the section heading when required (default "*"); blank shows none|
    )

    attr(:visible_if, :string)
    attr(:enable_if, :string)

    attr(:nested, :string, doc: "Place this nested form inside another <:nested> form's template")

    attr(:group, :string, doc: "Place this nested form inside a <:group> panel")
  end

  def form(%{render_only: true} = assigns) do
    assigns = assign(assigns, :dynamic_form_instance, get_instance(assigns))
    validate_form_assigns!(:render_only_form, assigns)

    assigns =
      assigns
      |> assign(:phx_change, assigns.phx_change || "validate")
      |> assign(:phx_submit, assigns.phx_submit || "submit")

    ~H"""
    <DynamicForm.Renderer.Component.render
      instance={@dynamic_form_instance}
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
    assigns = assign(assigns, :dynamic_form_instance, get_instance(assigns))
    validate_form_assigns!(:default_form, assigns)

    ~H"""
    <.live_component
      module={DynamicForm.Renderer.LiveComponent}
      id={@id}
      instance={@dynamic_form_instance}
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

  # Helpers

  defp validate_form_assigns!(:render_only_form, assigns) do
    # Render-only mode renders markup against a parent-owned form — attributes
    # that configure the managed lifecycle have no meaning there and raise.
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
      DynamicForm.Instance.Elements.list_file_questions(assigns.dynamic_form_instance.elements)

    if file_questions != [] do
      raise ArgumentError,
            "DynamicForm.form id=#{inspect(assigns.id)} render_only does not support " <>
              "file upload questions (#{Enum.map_join(file_questions, ", ", & &1.name)}) — " <>
              "uploads require the stateful component"
    end
  end

  defp validate_form_assigns!(:default_form, assigns) do
    # The stateful component owns the form and its events — the render-only
    # attributes conflict with that and raise.
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
  defp get_instance(assigns) do
    case definition_modes(assigns) do
      [:instance] ->
        assigns.instance

      [:json] ->
        decode_json!(assigns)

      [:slots] ->
        DynamicForm.Parser.Declarative.convert!(assigns)

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

  defp decode_json!(%{json: json}) when is_binary(json), do: DynamicForm.Instance.decode!(json)

  defp decode_json!(%{json: other} = assigns) do
    raise ArgumentError,
          "DynamicForm.form id=#{inspect(assigns.id)} json attribute must be a JSON " <>
            "string — for maps or Instance structs use the instance attribute. " <>
            "Got: #{inspect(other)}"
  end
end
