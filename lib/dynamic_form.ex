defmodule DynamicForm do
  @moduledoc """
  DynamicForm - A Phoenix LiveView library for creating dynamic forms with full
  backend validation using changesets and calls to backend functions. Also
  supports building forms through a WYSIWYG interface.

  This library enables users to build forms dynamically through a visual interface,
  then render those forms using standard Phoenix LiveView patterns with robust
  validation and backend integration.

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
      <DynamicForm.form id="contact-form" instance={@form_instance} send_messages />

      <%!-- Data mode: SurveyJS-compatible JSON string --%>
      <DynamicForm.form id="contact-form" json={@json} send_messages />

      <%!-- Declarative mode --%>
      <DynamicForm.form id="contact-form" title="Contact Form" send_messages>
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

  alias DynamicForm.Instance

  defdelegate submit_button(assigns), to: DynamicForm.RendererLive

  @doc """
  Renders a dynamic form from an instance, a SurveyJS-compatible JSON string,
  or `<:field>` slots (declarative mode).

  Wraps `DynamicForm.RendererLive`, which manages form state, validation, and
  backend submission. Exactly one of the `instance` attribute, the `json`
  attribute, or `<:field>` slots must be provided.

  ## Declarative mode

  `<:field>` entries convert to a `DynamicForm.Instance` in template order
  (see `DynamicForm.Instance.FromSlots`). Question types collect input;
  `html`, `image`, and `custom` render static or custom content:

      <DynamicForm.form id="signup" send_messages>
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

  Slot bodies are in-memory only: instances containing them JSON-encode
  without the bodies, and such forms cannot round-trip through the WYSIWYG
  builder.
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

  attr(:backend, :any,
    default: nil,
    doc: "Instance.Backend struct for form submission (declarative mode)"
  )

  attr(:params, :map, default: %{}, doc: "Initial form params for edit mode")
  attr(:form_name, :string, default: "dynamic_form", doc: "Form namespace for params")
  attr(:submit_text, :string, default: "Submit", doc: "Submit button text")

  attr(:send_messages, :boolean,
    default: false,
    doc: "Send {:dynamic_form_success, id, result} messages to the parent LiveView"
  )

  attr(:hide_submit, :boolean, default: false, doc: "Hide the submit button")
  attr(:gettext, :atom, default: DynamicForm.Gettext, doc: "Gettext backend for translations")

  attr(:validation_summary, :string,
    default: nil,
    doc: "Display validation errors at the top of the form: nil, \"simple\", or \"detailed\""
  )

  slot :field, doc: "Form elements in render order (declarative mode)" do
    attr(:type, :string,
      required: true,
      values: ~w(text comment dropdown radiogroup checkbox boolean rating tagbox file
                 html image custom),
      doc: "Question or element type"
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
  end

  def form(assigns) do
    assigns = assign(assigns, :resolved_instance, resolve_instance(assigns))

    ~H"""
    <.live_component
      module={DynamicForm.RendererLive}
      id={@id}
      instance={@resolved_instance}
      params={@params}
      form_name={@form_name}
      submit_text={@submit_text}
      send_messages={@send_messages}
      hide_submit={@hide_submit}
      gettext={@gettext}
      validation_summary={@validation_summary}
    />
    """
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
      slots: assigns.field != [] or assigns.group != []
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
