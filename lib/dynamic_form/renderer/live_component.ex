defmodule DynamicForm.Renderer.LiveComponent do
  @moduledoc """
  A LiveComponent version of the DynamicForm renderer with automatic state management.

  This component handles form state, validation, and submission automatically,
  communicating with the parent LiveView via message passing.

  ## Attributes

  ### Required

    * `:id` - Component ID (string, required by LiveComponent)
    * `:instance` - DynamicForm.Instance struct, JSON string, or map containing form configuration

  ### Optional

    * `:on_change` - 1-arity function `(payload) -> payload` run after the
      built-in validations on every change and during the submit validation
      pass (default: `nil`; see "Lifecycle callbacks" below)
    * `:change_debounce_in_ms` - Milliseconds of quiet before a change runs
      `on_change` and sends its `:change` message; without it both happen on
      every change (integer, default: `nil`; see "Debouncing changes" below)
    * `:on_submit` - 1-arity function `(payload) -> payload` run on every
      submit — valid or not (default: `nil`; see "Lifecycle callbacks" below)
    * `:on_success` - 1-arity function `(payload)` run on every valid
      submission *instead of* the `{:dynamic_form, :success, payload}` message
      to the parent LiveView (default: `nil`; see "Messages" below)
    * `:send_message_on` - Lifecycle events that message the parent LiveView:
      any of `[:success, :change, :submit]` (list, default: `[:success]`;
      see "Messages" below)
    * `:data` - Initial form data for edit mode — existing record values;
      a payload's `data` round-trips directly (map, default: `%{}`)
    * `:form_name` - Form namespace for submitted params (string, default: `"dynamic_form"`)
    * `:submit_text` - Submit button text (string, default: `"Submit"`, not required when `hide_submit` is `true`)
    * `:hide_submit` - Whether to hide the submit button (boolean, default: `false`)
    * `:gettext` - Gettext backend module for translations (atom, default: `DynamicForm.Gettext`)
    * `:validation_summary` - Display validation errors at top of form (string, `nil`, `"simple"`, or `"detailed"`, default: `nil`)
    * `:components` - Custom components module (e.g. the app's
      Phoenix-generated CoreComponents); functions it exports override the
      built-ins per function — see `DynamicForm.ComponentResolver` (atom, default:
      `nil`, falling back to the `:dynamic_form, :components` config)
    * `:custom_field_types` - Custom field types map (type name => Ecto
      type), merged over the `:dynamic_form, :custom_field_types` config —
      see `DynamicForm.FieldTypes` (map, default: `nil`)

  ## Usage

  ### Basic Usage

  The component sends the parent LiveView a message on every valid
  submission — the parent performs the side effect:

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="contact-form"
        instance={@form_instance}
      />

      def handle_info({:dynamic_form, :success, %DynamicForm.Payload{data: data}}, socket) do
        {:ok, contact} = MyApp.Contacts.create_contact(data)
        {:noreply, put_flash(socket, :info, "Created contact \#{contact.id}")}
      end

  ### Custom success handling

  Define `on_success` to replace the default message with your own behavior
  (a differently-shaped message, a PubSub broadcast, or nothing at all):

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="contact-form"
        instance={@form_instance}
        on_success={fn payload -> send(self(), {:contact_saved, payload.data}) end}
      />

  ### Edit Mode

  Pre-populate the form with existing data:

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="user-profile"
        instance={@form_instance}
        data={%{"name" => "John", "email" => "john@example.com"}}
        form_name="user_profile"
      />

  ### Read-only and disabled fields

  Questions marked `readOnly` are displayed but cannot be edited, and their
  values still submit: text controls render `readonly`, and controls HTML has
  no `readonly` for (selects, checkboxes, radios) render disabled alongside a
  hidden input carrying the value.

  A question disabled by `enableIf` is a different case — it is not part of
  this submission, so nothing carries its value. Extra keys in `:data` with
  no matching question are merged back into every submission regardless, so
  values like an `id` survive without a field of their own.

  ### External Submit Button

  You can place a submit button outside the form element by using the `hide_submit`
  option and `DynamicForm.Renderer.LiveComponent.submit_button/1` (which is
  aliased in the top level so can be called via `DynamicForm.submit_button/1`):

      <DynamicForm.submit_button form="my-form-form">
        Save Changes
      </DynamicForm.submit_button>

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="my-form"
        instance={@form_instance}
        hide_submit={true}
      />

  Note: The form ID is automatically generated as `"\#{id}-form"`, so if your component
  ID is "my-form", the form element ID will be "my-form-form".

  ## Lifecycle callbacks: `on_change` and `on_submit`

  Both hooks mirror the form's `phx-change`/`phx-submit` events. Each is a
  1-arity function that receives a `DynamicForm.Payload` — carrying the
  changeset after the built-in validations and the applied data — and
  returns the payload, transformed or untouched. Callbacks are for
  **validation**, not side effects: perform actions (database writes,
  navigation) in the parent's `handle_info/2` instead.

  `on_change` extends validation: it runs after the built-in validations on
  every change (and during the submit validation pass). Errors added via
  `DynamicForm.Payload.add_error/4` render inline live, exactly like
  built-in validations. Keep it cheap — it runs per keystroke.

  `on_submit` runs on **every** submit — valid or not — so it can batch
  expensive checks (API calls, database lookups) with the built-in errors
  into one complete error list:

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="contact-form"
        instance={@form_instance}
        on_submit={&MyApp.Contacts.verify/1}
      />

      def verify(payload) do
        case verify_phone_number(payload.data[:phone]) do   # expensive, submit-only
          {:ok, normalized} ->
            DynamicForm.Payload.put_extra(payload, :normalized_phone, normalized)

          :error ->
            DynamicForm.Payload.add_error(payload, :phone, "is not a valid phone number")
        end
      end

  ## Debouncing changes

  `change_debounce_in_ms` trades immediacy for fewer runs: `on_change` and
  the `:change` message wait for the given milliseconds of quiet instead of
  firing on every change.

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="signup-form"
        instance={@form_instance}
        on_change={&MyApp.Accounts.check_availability/1}
        change_debounce_in_ms={300}
      />

  The built-in validations still render on every change — only the callback
  and the message are deferred, so a debounced form is as responsive as an
  undebounced one. Each change supersedes the pending run, so work that costs
  more than a keystroke can afford (a database lookup, an API call, a parent
  re-render per `:change` message) happens once the user pauses rather than
  once per character.

  Between the change and the deferred run the callback's errors are absent:
  the changeset is rebuilt from the new params on every change, and the
  callback that would re-add them hasn't run yet. Submitting always runs
  `on_change` inline, so a debounced callback can never be skipped by
  submitting during the quiet period.

  A `nil` or `0` interval runs both inline, exactly as if the attribute were
  absent.

  ## Messages

  The component messages the parent LiveView with a lifecycle event and the
  payload:

      {:dynamic_form, event, %DynamicForm.Payload{}}

  `send_message_on` picks the events, defaulting to `[:success]`:

    * `:success` - a valid submission
    * `:change` - every change, after the built-in validations and
      `on_change` (debounced by `change_debounce_in_ms`)
    * `:submit` - every submit, valid or not, after `on_submit`

  A valid submission with all three enabled delivers `:change`, `:submit`,
  and `:success`, in that order. `:change` and `:submit` payloads are
  routinely invalid — check `DynamicForm.Payload.valid?/1` before acting on
  them. The payload delivered is the one returned by the callbacks (or built
  by the component when none are configured), so anything stashed in
  `:extra` is available in `handle_info/2`.

  Defining `on_success` **replaces** the success message: the function is
  called with the payload on every valid submission and no `:success`
  message is sent. Its return value is ignored. Use it to send a custom
  message, broadcast over PubSub, or make the form fully self-contained.
  Listing `:success` in `send_message_on` alongside `on_success` raises.

  Messages go to the LiveView process, so a LiveComponent parent can't
  receive them — have the callbacks call `Phoenix.LiveView.send_update/2`
  instead.
  """

  use Phoenix.LiveComponent
  import Phoenix.LiveView, only: [cancel_upload: 3]
  alias DynamicForm.Changeset
  alias DynamicForm.Helpers
  alias DynamicForm.Instance
  alias DynamicForm.Instance.Elements
  alias DynamicForm.Lifecycle.Debounce
  alias DynamicForm.Lifecycle.Uploads
  alias DynamicForm.NestedForms
  alias DynamicForm.Parser
  alias DynamicForm.Payload
  alias DynamicForm.Renderer.Component
  alias DynamicForm.Renderer.Components.ValidationSummary

  @message_events [:success, :change, :submit]

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Handle special update actions from child components
    cond do
      Map.has_key?(assigns, :action) && assigns.action == :delete_file ->
        handle_delete_file_update(assigns, socket)

      Map.has_key?(assigns, :action) && assigns.action == :cancel_upload ->
        handle_cancel_upload_update(assigns, socket)

      Map.has_key?(assigns, :action) && assigns.action == :run_change ->
        handle_run_change_update(assigns, socket)

      true ->
        handle_normal_update(assigns, socket)
    end
  end

  defp handle_normal_update(assigns, socket) do
    instance = Parser.JSON.parse!(assigns.instance)

    form_name = Map.get(assigns, :form_name, "dynamic_form")

    initial_data =
      assigns
      |> Map.get(:data, %{})
      |> apply_default_values(instance)

    if definition_unchanged?(socket, instance, initial_data, form_name) do
      # The form definition and initial data are the same — keep the live
      # changeset so a parent re-render doesn't wipe in-progress user input.
      # The fresh instance is still assigned because slot-defined elements may
      # carry new closures that must re-render with current parent assigns.
      {:ok,
       socket
       |> assign(assigns)
       |> assign_send_message_on(assigns)
       |> assign(:instance, instance)
       |> assign(:initial_data, initial_data)}
    else
      gettext = Map.get(assigns, :gettext, DynamicForm.Gettext)

      changeset =
        Changeset.create_changeset(instance, seed_entry_ids(initial_data, instance),
          custom_field_types: Map.get(assigns, :custom_field_types)
        )

      form = to_form(changeset, as: form_name)

      socket =
        socket
        |> assign(assigns)
        |> assign_send_message_on(assigns)
        |> assign(:instance, instance)
        |> assign(:changeset, changeset)
        |> assign(:form, form)
        |> assign(:form_name, form_name)
        |> assign(:initial_data, initial_data)
        |> assign(:gettext, gettext)
        |> assign(:submitting, false)
        # The form starts over, so a debounced change scheduled against the
        # previous definition or data no longer applies.
        |> Debounce.cancel()
        |> Uploads.allow(instance)

      {:ok, socket}
    end
  end

  # True when the component is already initialized and neither the form
  # definition nor the initial data changed. Instances are compared with
  # their slot entries stripped: slot bodies hold closures over the parent's
  # assigns, which compare unequal whenever those assigns change even though
  # the form definition itself is identical.
  defp definition_unchanged?(socket, instance, initial_data, form_name) do
    Map.has_key?(socket.assigns, :changeset) and
      form_name == socket.assigns.form_name and
      Instance.strip_slots(instance) == Instance.strip_slots(socket.assigns.instance) and
      initial_data == socket.assigns.initial_data
  end

  defp handle_delete_file_update(assigns, socket) do
    field_atom = String.to_atom(assigns.field_name)

    current_params =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.put(field_atom, assigns.remaining_files)

    changeset =
      DynamicForm.Changeset.create_changeset(socket.assigns.instance, current_params,
        custom_field_types: socket.assigns[:custom_field_types]
      )

    form = to_form(changeset, as: socket.assigns.form_name)

    {:ok, assign(socket, changeset: changeset, form: form)}
  end

  defp handle_cancel_upload_update(assigns, socket) do
    socket = cancel_upload(socket, assigns.upload_name, assigns.ref)
    {:ok, socket}
  end

  # A debounced change, delivered by the timer scheduled when the form
  # changed. The token fences a superseded run: canceling a timer can't
  # recall a message already sitting in the process mailbox, so a run whose
  # token no longer matches is dropped instead of applied over newer state.
  defp handle_run_change_update(%{token: token}, socket) do
    if Debounce.current?(socket, token) do
      {:ok, socket |> assign(:change_timer, nil) |> run_change()}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    hide_submit = Map.get(assigns, :hide_submit, false)
    submit_text = Map.get(assigns, :submit_text, "Submit")
    validation_summary = Map.get(assigns, :validation_summary, nil)
    uploads = assigns[:uploads] || %{}
    components = Map.get(assigns, :components)
    custom_field_types = Map.get(assigns, :custom_field_types)

    assigns =
      assigns
      |> assign(:hide_submit, hide_submit)
      |> assign(:submit_text, submit_text)
      |> assign(:validation_summary, validation_summary)
      |> assign(:uploads, uploads)
      |> assign(:components, components)
      |> assign(:custom_field_types, custom_field_types)

    ~H"""
    <div>
      <%= if @validation_summary && @changeset.action do %>
        <ValidationSummary.validation_summary
          changeset={@changeset}
          mode={@validation_summary}
          instance={@instance}
        />
      <% end %>
      <Component.render
        instance={@instance}
        form={@form}
        submit_text={@submit_text}
        phx_submit="submit"
        phx_change="validate"
        target={@myself}
        form_id={"#{@id}-form"}
        disabled={@submitting}
        hide_submit={@hide_submit}
        gettext={@gettext}
        uploads={@uploads}
        parent_id={@id}
        components={@components}
        custom_field_types={@custom_field_types}
      />
    </div>
    """
  end

  @impl true
  def handle_event("validate", params, socket) do
    form_params = Map.get(params, socket.assigns.form_name, %{})
    merged_params = merge_data(socket, form_params)

    changeset =
      Changeset.create_changeset(socket.assigns.instance, merged_params,
        custom_field_types: socket.assigns[:custom_field_types]
      )

    {:noreply, apply_change(socket, changeset)}
  end

  # Append a freshly seeded entry to a paneldynamic question's value. `path`
  # is the dot-separated location of the question in the params tree
  # ("addresses", or "contacts.0.phones" when nested inside another
  # nested form).
  @impl true
  def handle_event("add_nested_entry", %{"path" => path}, socket) do
    segments = String.split(path, ".")
    question = NestedForms.find_question(socket.assigns.instance.elements, segments)
    seed = NestedForms.new_entry(question)

    params =
      NestedForms.update_entry_list(socket.assigns.changeset.params, segments, fn entries ->
        entries ++ [seed]
      end)

    {:noreply, rebuild_form(socket, params)}
  end

  @impl true
  def handle_event("remove_nested_entry", %{"path" => path, "index" => index}, socket) do
    segments = String.split(path, ".")
    index = String.to_integer(index)

    params =
      NestedForms.update_entry_list(socket.assigns.changeset.params, segments, fn entries ->
        List.delete_at(entries, index)
      end)

    {:noreply, rebuild_form(socket, params)}
  end

  @impl true
  def handle_event("submit", params, socket) do
    form_params = Map.get(params, socket.assigns.form_name, %{})
    merged_params = merge_data(socket, form_params)

    # Submitting supersedes any debounced run: the change pass always runs
    # inline here, so a submit during the quiet period can't skip it.
    socket =
      socket
      |> Debounce.cancel()
      |> assign(:submitting, true)

    changed =
      socket.assigns.instance
      |> Changeset.create_changeset(merged_params,
        custom_field_types: socket.assigns[:custom_field_types]
      )
      |> create_payload(socket)
      |> apply_callback(socket, :on_change)

    socket = send_message(socket, :change, changed)
    payload = apply_callback(changed, socket, :on_submit)
    socket = send_message(socket, :submit, payload)

    if Payload.valid?(payload) do
      {:noreply,
       socket
       |> handle_success(payload)
       |> assign(:submitting, false)}
    else
      {:noreply, handle_invalid_submit(socket, payload.changeset)}
    end
  end

  # Helpers - Data

  # Seed initial data with each question's defaultValue. Explicitly provided
  # params always win over defaults.
  defp apply_default_values(params, instance) do
    params = Helpers.Map.deep_stringify_keys(params)
    questions = Elements.list_questions(instance.elements)

    questions
    |> Enum.reduce(params, fn question, acc ->
      case question.defaultValue do
        nil -> acc
        default -> Map.put_new(acc, question.name, default)
      end
    end)
    |> NestedForms.seed_entries(questions)
  end

  # Entry ids are form state, not initial data. `initial_data` is compared on
  # every parent re-render to decide whether the form resets, so generating
  # ids into it would make it differ every time and wipe in-progress input —
  # they are seeded into the changeset's params instead.
  defp seed_entry_ids(params, instance) do
    NestedForms.seed_entry_ids(params, Elements.list_questions(instance.elements))
  end

  # Revalidate after an entry add/remove: adding or removing an entry
  # changes the form's data, so it runs the change pass like any other. A
  # freshly added entry gets its id here — existing entries keep theirs.
  defp rebuild_form(socket, params) do
    socket.assigns.instance
    |> Changeset.create_changeset(seed_entry_ids(params, socket.assigns.instance),
      custom_field_types: socket.assigns[:custom_field_types]
    )
    |> then(&apply_change(socket, &1))
  end

  # Render a rebuilt changeset, preserving the current action so error
  # display doesn't change mid-edit.
  defp assign_changeset(socket, changeset) do
    changeset = Map.put(changeset, :action, socket.assigns.changeset.action)

    socket
    |> assign(:changeset, changeset)
    |> assign(:form, to_form(changeset, as: socket.assigns.form_name))
  end

  # The params a change or submit validates against, in three layers —
  # weakest first:
  #
  #   1. the data the parent passed in, the only source for keys the form has
  #      never rendered. Editing an existing record often carries extra
  #      fields like `id` that no question collects, and they survive here.
  #
  #   2. what the form is currently holding. Browsers submit nothing for a
  #      section hidden by `visible_if` or a question disabled by
  #      `enable_if`, so without this those values would rewind to whatever
  #      the form was loaded with — discarding edits made while the section
  #      was visible, along with its entries' ids.
  #
  #   3. what the browser just sent, which always wins.
  #
  # A parent that passes different `data` doesn't reach this: that rebuilds
  # the form (see definition_unchanged?/4), so the new data still wins.
  defp merge_data(socket, form_params) do
    socket.assigns.initial_data
    |> Helpers.Map.deep_stringify_keys()
    |> Map.merge(held_params(socket))
    |> Map.merge(Helpers.Map.deep_stringify_keys(form_params))
  end

  # The params the current changeset was built from — already string-keyed,
  # and holding raw values rather than cast ones, so a half-typed number
  # survives a section being hidden the same way a valid one does.
  defp held_params(socket) do
    case socket.assigns[:changeset] do
      %Ecto.Changeset{params: params} when is_map(params) -> params
      _ -> %{}
    end
  end

  # Helpers - Handlers

  defp create_payload(changeset, socket) do
    Payload.new(socket.assigns.id, changeset)
  end

  # Pipe the payload through a lifecycle callback when one is given.
  # on_change runs after the built-in validations, on every change and
  # during the submit validation pass; on_submit runs on every submit —
  # valid or not — so it can batch expensive checks with the built-in
  # errors into one complete error list.
  defp apply_callback(payload, socket, name) do
    case socket.assigns[name] do
      nil ->
        payload

      fun when is_function(fun, 1) ->
        case fun.(payload) do
          %Payload{} = payload ->
            payload

          other ->
            raise ArgumentError,
                  "#{name} must return a DynamicForm.Payload, got: #{inspect(other)}"
        end

      other ->
        raise ArgumentError,
              "#{name} must be a 1-arity function receiving a DynamicForm.Payload, " <>
                "got: #{inspect(other)}"
    end
  end

  # The form changed: render the built-in validations now, then run the
  # change pass — on_change and the :change message — inline or after the
  # debounce interval.
  defp apply_change(socket, changeset) do
    socket = assign_changeset(socket, changeset)

    case Debounce.interval(socket) do
      nil -> run_change(socket)
      interval -> Debounce.schedule(socket, interval)
    end
  end

  # The change pass against the current changeset. Shared by the inline and
  # debounced paths so both deliver the same payload.
  defp run_change(socket) do
    payload =
      socket.assigns.changeset
      |> create_payload(socket)
      |> apply_callback(socket, :on_change)

    socket
    |> assign_changeset(payload.changeset)
    |> send_message(:change, payload)
  end

  # Helpers - Messages

  # Resolve the lifecycle events that message the parent, rejecting a
  # combination that can't be honored.
  defp assign_send_message_on(socket, assigns) do
    events =
      case Map.get(assigns, :send_message_on) do
        nil ->
          [:success]

        events when is_list(events) ->
          validate_message_events!(events, socket)

        other ->
          raise ArgumentError,
                "send_message_on must be a list of #{inspect(@message_events)}, " <>
                  "got: #{inspect(other)}"
      end

    assign(socket, :send_message_on, events)
  end

  defp validate_message_events!(events, socket) do
    case Enum.reject(events, &(&1 in @message_events)) do
      [] -> :ok
      unknown -> raise ArgumentError, "send_message_on got unknown events: #{inspect(unknown)}"
    end

    if :success in events and socket.assigns[:on_success] do
      raise ArgumentError,
            "send_message_on includes :success while on_success is set — on_success " <>
              "replaces the success message. Remove one."
    end

    events
  end

  defp send_message(socket, event, payload) do
    if event in socket.assigns.send_message_on do
      send(self(), {:dynamic_form, event, payload})
    end

    socket
  end

  # Render the failed changeset's errors inline.
  defp handle_invalid_submit(socket, changeset) do
    changeset = Map.put(changeset, :action, :validate)
    form = to_form(changeset, as: socket.assigns.form_name)

    socket
    |> assign(:changeset, changeset)
    |> assign(:form, form)
    |> assign(:submitting, false)
  end

  # Complete a valid submission: message the parent LiveView, or hand the
  # payload to a custom on_success callback when one is given — the callback
  # replaces the message entirely.
  defp handle_success(socket, payload) do
    case socket.assigns[:on_success] do
      nil ->
        send_message(socket, :success, payload)

      fun when is_function(fun, 1) ->
        fun.(payload)
        socket

      other ->
        raise ArgumentError,
              "on_success must be a 1-arity function receiving a DynamicForm.Payload, " <>
                "got: #{inspect(other)}"
    end
  end

  # Public API

  @doc """
  Renders a submit button that can be placed outside a form element.

  Uses the HTML `form` attribute to associate the button with a form by its ID.
  This allows the submit button to be placed anywhere on the page, not just
  inside the form element.

  When using with `DynamicForm.Renderer.LiveComponent`, the form ID is automatically
  generated as `"\#{component_id}-form"`. For example, if your LiveComponent
  has `id="my-form"`, the form element ID will be `"my-form-form"`.

  ## Examples

      # LiveComponent with external submit button
      <DynamicForm.submit_button form="contact-form-form">
        Submit Contact Form
      </DynamicForm.submit_button>

      <.live_component
        module={DynamicForm.Renderer.LiveComponent}
        id="contact-form"
        instance={@form_instance}
        hide_submit={true}
      />

      # In a modal footer
      <.modal id="edit-modal">
        <.live_component
          module={DynamicForm.Renderer.LiveComponent}
          id="user-profile"
          instance={@form_instance}
          hide_submit={true}
        />
        <:actions>
          <DynamicForm.submit_button form="user-profile-form">
            Save Profile
          </DynamicForm.submit_button>
        </:actions>
      </.modal>

  ## Attributes

    * `form` - The ID of the form element to submit (required)
    * `class` - Additional CSS classes to apply to the button
    * `disabled` - Whether the button is disabled
  """
  attr(:form, :string, required: true, doc: "The ID of the form element to submit")
  attr(:class, :string, default: nil, doc: "Additional CSS classes")
  attr(:disabled, :boolean, default: false, doc: "Whether the button is disabled")
  attr(:rest, :global, include: ~w(name value))

  slot(:inner_block, required: true)

  def submit_button(assigns) do
    ~H"""
    <button
      type="submit"
      form={@form}
      disabled={@disabled}
      class={["phx-submit-loading:opacity-75 btn btn-primary", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end
