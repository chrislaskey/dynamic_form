defmodule DynamicForm.RendererLive do
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
      built-ins per function — see `DynamicForm.Components` (atom, default:
      `nil`, falling back to the `:dynamic_form, :components` config)
    * `:custom_field_types` - Custom field types map (type name => Ecto
      type), merged over the `:dynamic_form, :custom_field_types` config —
      see `DynamicForm.FieldTypes` (map, default: `nil`)

  ## Usage

  ### Basic Usage

  The component sends the parent LiveView a message on every valid
  submission — the parent performs the side effect:

      <.live_component
        module={DynamicForm.RendererLive}
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
        module={DynamicForm.RendererLive}
        id="contact-form"
        instance={@form_instance}
        on_success={fn payload -> send(self(), {:contact_saved, payload.data}) end}
      />

  ### Edit Mode

  Pre-populate the form with existing data:

      <.live_component
        module={DynamicForm.RendererLive}
        id="user-profile"
        instance={@form_instance}
        data={%{"name" => "John", "email" => "john@example.com"}}
        form_name="user_profile"
      />

  ### Disabled Fields

  Fields can be marked as `disabled: true` in the form instance configuration.
  Disabled fields are displayed but cannot be edited by the user.

  **Important**: Disabled HTML fields are not submitted by browsers, so their values
  are automatically preserved by merging the initial `:data` with form submissions.
  This ensures disabled field values remain in the changeset throughout validation
  and submission.

  ### External Submit Button

  You can place a submit button outside the form element by using the `hide_submit`
  option and `DynamicForm.RendererLive.submit_button/1`:

      <DynamicForm.RendererLive.submit_button form="my-form-form">
        Save Changes
      </DynamicForm.RendererLive.submit_button>

      <.live_component
        module={DynamicForm.RendererLive}
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
        module={DynamicForm.RendererLive}
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
        module={DynamicForm.RendererLive}
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
  import Phoenix.LiveView, only: [allow_upload: 3, cancel_upload: 3, send_update_after: 3]
  alias DynamicForm.{Renderer, Changeset, Instance, NestedForms, Payload}

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
    # Decode instance if needed
    instance = decode_instance(assigns.instance)

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
        Changeset.create_changeset(instance, initial_data,
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
        |> cancel_debounced_change()
        |> allow_uploads_for_direct_upload_fields(instance)

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
    if token == socket.assigns[:change_token] do
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
        <.validation_summary_component
          changeset={@changeset}
          mode={@validation_summary}
          instance={@instance}
        />
      <% end %>
      <Renderer.render
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
    merged_params = merge_data(socket.assigns.initial_data, form_params)

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
      update_entry_list(socket.assigns.changeset.params, segments, fn entries ->
        entries ++ [seed]
      end)

    {:noreply, rebuild_form(socket, params)}
  end

  @impl true
  def handle_event("remove_nested_entry", %{"path" => path, "index" => index}, socket) do
    segments = String.split(path, ".")
    index = String.to_integer(index)

    params =
      update_entry_list(socket.assigns.changeset.params, segments, fn entries ->
        List.delete_at(entries, index)
      end)

    {:noreply, rebuild_form(socket, params)}
  end

  @impl true
  def handle_event("submit", params, socket) do
    form_params = Map.get(params, socket.assigns.form_name, %{})
    merged_params = merge_data(socket.assigns.initial_data, form_params)

    # Submitting supersedes any debounced run: the change pass always runs
    # inline here, so a submit during the quiet period can't skip it.
    socket =
      socket
      |> cancel_debounced_change()
      |> assign(:submitting, true)

    changed =
      socket.assigns.instance
      |> Changeset.create_changeset(merged_params,
        custom_field_types: socket.assigns[:custom_field_types]
      )
      |> build_payload(socket)
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
    params = recursively_convert_to_string_keys(params)

    instance.elements
    |> Changeset.get_questions()
    |> Enum.reduce(params, fn question, acc ->
      case question.defaultValue do
        nil -> acc
        default -> Map.put_new(acc, question.name, default)
      end
    end)
    |> seed_nested_entries(instance)
  end

  # Paneldynamic questions without initial data start with panelCount seeded
  # entries (at least minPanelCount), mirroring SurveyJS.
  defp seed_nested_entries(params, instance) do
    instance.elements
    |> Changeset.get_questions()
    |> Enum.filter(&(&1.type == "paneldynamic"))
    |> Enum.reduce(params, fn question, acc ->
      count = max(question.panelCount || 0, question.minPanelCount || 0)
      entries = List.duplicate(NestedForms.new_entry(question), count)
      Map.put_new(acc, question.name, entries)
    end)
  end

  # Walk the params tree along a dot-separated entry path and update the
  # entry list at its end. Intermediate segments alternate between map keys
  # (question names) and list indexes (entries).
  defp update_entry_list(params, [name], fun) when is_map(params) do
    entries = params |> Map.get(name) |> NestedForms.entries()
    Map.put(params, name, fun.(entries))
  end

  defp update_entry_list(params, [name | rest], fun) when is_map(params) do
    Map.put(params, name, update_entry_list(Map.get(params, name) || %{}, rest, fun))
  end

  defp update_entry_list(entries, [index | rest], fun) when is_list(entries) do
    List.update_at(entries, String.to_integer(index), &update_entry_list(&1, rest, fun))
  end

  # Revalidate after an entry add/remove: adding or removing an entry
  # changes the form's data, so it runs the change pass like any other.
  defp rebuild_form(socket, params) do
    socket.assigns.instance
    |> Changeset.create_changeset(params,
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

  defp merge_data(initial_data, changeset_data) do
    # Merging data helps solve a few different scenarios:
    #
    # - Editing an existing record that has additional fields like `id` we want
    #   to preserve. Technically this can be done in the form instance by
    #   including a hidden `id` field but it's easy to miss. Especially if
    #   using a WYSIWYG editor and are unfamiliar with forms.
    #
    # - Handling disabled fields. Disabled inputs aren't included in the changeset
    #   which can cause disabled field values to disappear.
    #
    initial = recursively_convert_to_string_keys(initial_data)
    changeset = recursively_convert_to_string_keys(changeset_data)

    Map.merge(initial, changeset)
  end

  defp recursively_convert_to_string_keys(%Decimal{} = value), do: value

  defp recursively_convert_to_string_keys(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> recursively_convert_to_string_keys()
  end

  defp recursively_convert_to_string_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      string_key = to_string(key)
      converted_value = recursively_convert_to_string_keys(value)

      {string_key, converted_value}
    end)
  end

  defp recursively_convert_to_string_keys(list) when is_list(list) do
    Enum.map(list, &recursively_convert_to_string_keys/1)
  end

  defp recursively_convert_to_string_keys(value), do: value

  # Helpers - Handlers

  defp build_payload(changeset, socket) do
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

    case change_debounce(socket) do
      nil -> run_change(socket)
      interval -> schedule_debounced_change(socket, interval)
    end
  end

  # The change pass against the current changeset. Shared by the inline and
  # debounced paths so both deliver the same payload.
  defp run_change(socket) do
    payload =
      socket.assigns.changeset
      |> build_payload(socket)
      |> apply_callback(socket, :on_change)

    socket
    |> assign_changeset(payload.changeset)
    |> send_message(:change, payload)
  end

  # The debounce interval for the change pass, or nil when it runs inline:
  # nothing to defer, no interval, or an interval of zero.
  defp change_debounce(socket) do
    case socket.assigns[:change_debounce_in_ms] do
      nil ->
        nil

      0 ->
        nil

      interval when is_integer(interval) and interval > 0 ->
        if deferrable_change?(socket), do: interval, else: nil

      other ->
        raise ArgumentError,
              "change_debounce_in_ms must be a non-negative integer of milliseconds, " <>
                "got: #{inspect(other)}"
    end
  end

  defp deferrable_change?(socket) do
    not is_nil(socket.assigns[:on_change]) or :change in socket.assigns.send_message_on
  end

  # Debounce the change pass: drop the run this change supersedes and
  # schedule a fresh one. LiveComponents have no handle_info/2, so the timer
  # arrives back through update/2 as a :run_change action.
  defp schedule_debounced_change(socket, interval) do
    socket = cancel_debounced_change(socket)
    token = socket.assigns.change_token

    timer =
      send_update_after(
        __MODULE__,
        [id: socket.assigns.id, action: :run_change, token: token],
        interval
      )

    assign(socket, :change_timer, timer)
  end

  # Drop any pending debounced run and issue the token the next one will
  # carry. Canceling the timer is the fast path; the token is what makes a
  # run already in the mailbox a no-op when it arrives.
  defp cancel_debounced_change(socket) do
    case socket.assigns[:change_timer] do
      nil -> :ok
      timer -> Process.cancel_timer(timer)
    end

    socket
    |> assign(:change_timer, nil)
    |> assign(:change_token, (socket.assigns[:change_token] || 0) + 1)
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

  # Renders a validation summary component showing form errors.
  #
  # This component displays validation errors at the top of the form when the changeset
  # has errors and an action has been set (indicating validation has been triggered).
  #
  # Modes:
  #   * "simple" - Shows a generic message about filling out required fields
  #   * "detailed" - Shows the generic message plus a list of specific field errors
  defp validation_summary_component(assigns) do
    errors = get_changeset_errors(assigns.changeset)
    has_errors = length(errors) > 0

    assigns =
      assigns
      |> assign(:has_errors, has_errors)
      |> assign(:errors, errors)

    ~H"""
    <%= if @has_errors do %>
      <div class="rounded-md bg-red-50 p-4 mb-6">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg
              class="h-5 w-5 text-red-400"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
            >
              <path
                fill-rule="evenodd"
                d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z"
                clip-rule="evenodd"
              />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">
              You must fill out all required fields before marking the section as complete.
            </h3>
            <%= if @mode == "detailed" do %>
              <div class="mt-2 text-sm text-red-700">
                <ul role="list" class="list-disc space-y-1 pl-5">
                  <%= for {field, message} <- @errors do %>
                    <li>
                      <span class="font-medium"><%= humanize_field_name(field, @instance) %>:</span>
                      <%= message %>
                    </li>
                  <% end %>
                </ul>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a submit button that can be placed outside a form element.

  Uses the HTML `form` attribute to associate the button with a form by its ID.
  This allows the submit button to be placed anywhere on the page, not just
  inside the form element.

  When using with `DynamicForm.RendererLive`, the form ID is automatically
  generated as `"\#{component_id}-form"`. For example, if your LiveComponent
  has `id="my-form"`, the form element ID will be `"my-form-form"`.

  ## Examples

      # LiveComponent with external submit button
      <DynamicForm.RendererLive.submit_button form="contact-form-form">
        Submit Contact Form
      </DynamicForm.RendererLive.submit_button>

      <.live_component
        module={DynamicForm.RendererLive}
        id="contact-form"
        instance={@form_instance}
        hide_submit={true}
      />

      # In a modal footer
      <.modal id="edit-modal">
        <.live_component
          module={DynamicForm.RendererLive}
          id="user-profile"
          instance={@form_instance}
          hide_submit={true}
        />
        <:actions>
          <DynamicForm.RendererLive.submit_button form="user-profile-form">
            Save Profile
          </DynamicForm.RendererLive.submit_button>
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

  # Helper to decode instance from various formats
  defp decode_instance(%Instance{} = instance), do: instance

  defp decode_instance(data) when is_binary(data) or is_map(data) do
    Instance.decode!(data)
  end

  # Helper to extract errors from changeset
  defp get_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      messages
      |> List.wrap()
      |> Enum.map(fn message -> {field, message} end)
    end)
  end

  # Helper to humanize field names by looking up the title in the instance
  defp humanize_field_name(field_atom, instance) do
    field_name = to_string(field_atom)

    # Search through instance elements to find the question and get its title
    case find_question_by_name(instance.elements, field_name) do
      %{title: title} when is_binary(title) and title != "" -> title
      _ -> humanize_atom(field_atom)
    end
  end

  # Helper to find a question by name in the instance elements
  defp find_question_by_name(elements, name) when is_list(elements) do
    Enum.find_value(elements, fn element ->
      case element do
        %Instance.Question{name: ^name} = question ->
          question

        %Instance.Element{elements: nested_elements} when is_list(nested_elements) ->
          find_question_by_name(nested_elements, name)

        _ ->
          nil
      end
    end)
  end

  defp find_question_by_name(_, _), do: nil

  # Helper to humanize an atom (fallback when label not found)
  defp humanize_atom(atom) do
    atom
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Helper to set up uploads for file upload questions
  defp allow_uploads_for_direct_upload_fields(socket, instance) do
    file_upload_questions = find_file_upload_questions(instance.elements)

    Enum.reduce(file_upload_questions, socket, fn question, acc_socket ->
      metadata = question.metadata || %{}
      max_entries = get_in(metadata, ["max_entries"]) || 3
      max_file_size = get_in(metadata, ["max_file_size"]) || 10_000_000
      accept = get_in(metadata, ["accept"]) || :any

      upload_name = String.to_atom("upload_#{question.name}")

      allow_upload(acc_socket, upload_name,
        accept: accept,
        max_entries: max_entries,
        max_file_size: max_file_size,
        auto_upload: true,
        external: fn entry, socket ->
          presign_upload_entry(entry, socket, question, metadata)
        end,
        progress: fn _upload_name, entry, socket ->
          handle_upload_progress(entry, socket, question)
        end
      )
    end)
  end

  defp find_file_upload_questions(elements) do
    Enum.flat_map(elements, fn element ->
      case element do
        %Instance.Question{type: "file"} ->
          [element]

        %Instance.Element{elements: nested_elements} when is_list(nested_elements) ->
          find_file_upload_questions(nested_elements)

        _ ->
          []
      end
    end)
  end

  defp presign_upload_entry(entry, socket, question, metadata) do
    presigner_config = get_in(metadata, ["presigner"]) || %{}
    presigner_module = get_in(presigner_config, ["module"])
    presigner_function = get_in(presigner_config, ["function"]) || "sign"

    # Build context for presigner
    context = %{
      bucket: get_in(metadata, ["bucket"]),
      prefix: get_in(metadata, ["object_name_prefix"]) || "",
      field_name: question.name
    }

    # Generate presigned URL
    url =
      if presigner_module do
        module = String.to_existing_atom("Elixir.#{presigner_module}")
        function = String.to_existing_atom(presigner_function)
        apply(module, function, [entry.client_name, context])
      else
        require Logger

        Logger.warning(
          "No presigner configured for file upload question '#{question.name}'. Upload will fail."
        )

        ""
      end

    {:ok, %{uploader: "GoogleStorage", url: url}, socket}
  end

  defp handle_upload_progress(entry, socket, question) do
    if entry.done? do
      # Get current uploaded files for this question
      field_atom = String.to_atom(question.name)
      current_files = Phoenix.HTML.Form.input_value(socket.assigns.form, field_atom) || []

      # Add new file metadata
      metadata = question.metadata || %{}
      bucket = get_in(metadata, ["bucket"])
      prefix = get_in(metadata, ["object_name_prefix"]) || ""
      object_name = "#{prefix}#{entry.client_name}"

      {:ok, uploaded_on} = DateTime.shift_zone(DateTime.utc_now(), "America/Denver")
      uploaded_on_display = Calendar.strftime(uploaded_on, "%m/%d/%Y")

      file_data = %{
        "filename" => entry.client_name,
        "cloud_bucket" => bucket,
        "cloud_path" => object_name,
        "cloud_provider" => "gcp",
        "uploaded_on" => uploaded_on_display
      }

      # Remove duplicates and add new file
      updated_files =
        Enum.reject(current_files, &(&1["filename"] == entry.client_name)) ++ [file_data]

      # Note: We don't need to explicitly consume the entry for external uploads
      # The entry is automatically consumed when the external upload completes

      # Update the form with the new file data
      current_params =
        socket.assigns.changeset
        |> Ecto.Changeset.apply_changes()
        |> Map.put(field_atom, updated_files)

      changeset =
        DynamicForm.Changeset.create_changeset(socket.assigns.instance, current_params,
          custom_field_types: socket.assigns[:custom_field_types]
        )

      form = to_form(changeset, as: socket.assigns.form_name)

      {:noreply, assign(socket, changeset: changeset, form: form)}
    else
      {:noreply, socket}
    end
  end
end
