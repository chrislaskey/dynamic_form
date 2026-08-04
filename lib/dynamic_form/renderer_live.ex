defmodule DynamicForm.RendererLive do
  @moduledoc """
  A LiveComponent version of the DynamicForm renderer with automatic state management.

  This component handles form state, validation, and backend submission automatically,
  communicating with the parent LiveView via message passing.

  ## Attributes

  ### Required

    * `:id` - Component ID (string, required by LiveComponent)
    * `:instance` - DynamicForm.Instance struct, JSON string, or map containing form configuration

  ### Optional

    * `:params` - Initial form params for edit mode (map, default: `%{}`)
    * `:form_name` - Form namespace for params (string, default: `"dynamic_form"`)
    * `:submit_text` - Submit button text (string, default: `"Submit"`, not required when `hide_submit` is `true`)
    * `:send_messages` - Whether to send messages to parent LiveView (boolean, default: `false`)
    * `:hide_submit` - Whether to hide the submit button (boolean, default: `false`)
    * `:gettext` - Gettext backend module for translations (atom, default: `DynamicForm.Gettext`)
    * `:validation_summary` - Display validation errors at top of form (string, `nil`, `"simple"`, or `"detailed"`, default: `nil`)

  ## Usage

  ### Basic Usage with Message Passing

  Component sends messages to parent LiveView on form submission:

      <.live_component
        module={DynamicForm.RendererLive}
        id="contact-form"
        instance={@form_instance}
        send_messages={true}
      />

      def handle_info({:dynamic_form_submit, _id, {:ok, %{result: result}}}, socket) do
        {:noreply, put_flash(socket, :info, result.message)}
      end

  ### No Messages (Self-Contained)

  Component handles everything internally:

      <.live_component
        module={DynamicForm.RendererLive}
        id="contact-form"
        instance={@form_instance}
      />

  ### Edit Mode

  Pre-populate the form with existing data:

      <.live_component
        module={DynamicForm.RendererLive}
        id="user-profile"
        instance={@form_instance}
        params={%{"name" => "John", "email" => "john@example.com"}}
        form_name="user_profile"
        send_messages={true}
      />

  ### Disabled Fields

  Fields can be marked as `disabled: true` in the form instance configuration.
  Disabled fields are displayed but cannot be edited by the user.

  **Important**: Disabled HTML fields are not submitted by browsers, so their values
  are automatically preserved by merging the initial `:params` with form submissions.
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
        send_messages={true}
      />

  Note: The form ID is automatically generated as `"\#{id}-form"`, so if your component
  ID is "my-form", the form element ID will be "my-form-form".

  ## Backend Function

  The backend function specified in the form instance is called on every form submission with the following signature:

      backend_function(data, changeset, config)

  Where:
    * `data` - The form data (Ecto.Changeset.apply_changes/1 result)
    * `changeset` - The Ecto.Changeset (may be valid or invalid)
    * `config` - Keyword list of backend configuration from the form instance

  **Important**: The backend function is called regardless of changeset validity. This gives
  the application full control over validation and processing. Check `changeset.valid?` to
  determine if built-in validations passed.

  The backend function must return:
    * `{:cont, result}` - Continue with success, where result is passed to success handlers
    * `{:halt, %Ecto.Changeset{}}` - Halt with validation errors to display on the form
    * `{:halt, error}` - Halt with a general error

  Example backend function that adds custom errors:

      def process_form(data, changeset, config) do
        # Check if basic validations passed
        if not changeset.valid? do
          {:halt, changeset}
        else
          # Custom validation logic
          if email_already_exists?(data.email) do
            {:halt, Ecto.Changeset.add_error(changeset, :email, "already taken")}
          else
            case save_to_database(data, config) do
              {:ok, result} -> {:cont, %{message: "Saved!", data: result}}
              {:error, reason} -> {:halt, %{message: "Failed"}}
            end
          end
        end
      end

  ## Messages

  When `send_messages` is `true`, the component sends the parent LiveView a
  message on every submission, carrying the outcome as an ok/error tuple:

    * `{:dynamic_form_submit, id, {:ok, %{result: result, data: data}}}` -
      Submission succeeded. `result` is the backend's map (typically
      `:message` and `:data`), or `%{}` when no backend is configured; `data`
      is the applied changeset data.
    * `{:dynamic_form_submit, id, {:error, %{changeset: changeset, reason: reason}}}` -
      Submission failed. `changeset` carries the errors rendered inline;
      `reason` is a backend's non-changeset `{:halt, reason}` term, or `nil`.
  """

  use Phoenix.LiveComponent
  import Phoenix.LiveView, only: [allow_upload: 3, cancel_upload: 3]
  alias DynamicForm.{Renderer, Changeset, Instance}

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

      true ->
        handle_normal_update(assigns, socket)
    end
  end

  defp handle_normal_update(assigns, socket) do
    # Decode instance if needed
    instance = decode_instance(assigns.instance)

    form_name = Map.get(assigns, :form_name, "dynamic_form")

    initial_params =
      assigns
      |> Map.get(:params, %{})
      |> apply_default_values(instance)

    if definition_unchanged?(socket, instance, initial_params, form_name) do
      # The form definition and initial params are the same — keep the live
      # changeset so a parent re-render doesn't wipe in-progress user input.
      # The fresh instance is still assigned because slot-defined elements may
      # carry new closures that must re-render with current parent assigns.
      {:ok,
       socket
       |> assign(assigns)
       |> assign(:instance, instance)
       |> assign(:initial_params, initial_params)}
    else
      gettext = Map.get(assigns, :gettext, DynamicForm.Gettext)
      changeset = Changeset.create_changeset(instance, initial_params)
      form = to_form(changeset, as: form_name)

      socket =
        socket
        |> assign(assigns)
        |> assign(:instance, instance)
        |> assign(:changeset, changeset)
        |> assign(:form, form)
        |> assign(:form_name, form_name)
        |> assign(:initial_params, initial_params)
        |> assign(:gettext, gettext)
        |> assign(:submitting, false)
        |> allow_uploads_for_direct_upload_fields(instance)

      {:ok, socket}
    end
  end

  # True when the component is already initialized and neither the form
  # definition nor the initial params changed. Instances are compared with
  # their slot entries stripped: slot bodies hold closures over the parent's
  # assigns, which compare unequal whenever those assigns change even though
  # the form definition itself is identical.
  defp definition_unchanged?(socket, instance, initial_params, form_name) do
    Map.has_key?(socket.assigns, :changeset) and
      form_name == socket.assigns.form_name and
      Instance.strip_slots(instance) == Instance.strip_slots(socket.assigns.instance) and
      initial_params == socket.assigns.initial_params
  end

  defp handle_delete_file_update(assigns, socket) do
    field_atom = String.to_atom(assigns.field_name)

    current_params =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> Map.put(field_atom, assigns.remaining_files)

    changeset = DynamicForm.Changeset.create_changeset(socket.assigns.instance, current_params)
    form = to_form(changeset, as: socket.assigns.form_name)

    {:ok, assign(socket, changeset: changeset, form: form)}
  end

  defp handle_cancel_upload_update(assigns, socket) do
    socket = cancel_upload(socket, assigns.upload_name, assigns.ref)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    hide_submit = Map.get(assigns, :hide_submit, false)
    submit_text = Map.get(assigns, :submit_text, "Submit")
    validation_summary = Map.get(assigns, :validation_summary, nil)
    uploads = assigns[:uploads] || %{}

    assigns =
      assigns
      |> assign(:hide_submit, hide_submit)
      |> assign(:submit_text, submit_text)
      |> assign(:validation_summary, validation_summary)
      |> assign(:uploads, uploads)

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
      />
    </div>
    """
  end

  @impl true
  def handle_event("validate", params, socket) do
    form_params = Map.get(params, socket.assigns.form_name, %{})
    merged_params = merge_data(socket.assigns.initial_params, form_params)

    changeset =
      socket.assigns.instance
      |> Changeset.create_changeset(merged_params)
      |> Map.put(:action, socket.assigns.changeset.action)

    form = to_form(changeset, as: socket.assigns.form_name)

    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("submit", params, socket) do
    form_params = Map.get(params, socket.assigns.form_name, %{})
    merged_params = merge_data(socket.assigns.initial_params, form_params)

    changeset =
      socket.assigns.instance
      |> Changeset.create_changeset(merged_params)
      |> Map.put(:action, :updated)

    data = Ecto.Changeset.apply_changes(changeset)
    instance = socket.assigns.instance
    socket = assign(socket, :submitting, true)

    # Submit via backend if configured, otherwise succeed on a valid changeset
    if instance.backend do
      backend_module = instance.backend.module
      backend_function = instance.backend.function
      backend_config = Map.get(instance.backend, :config, [])

      case apply(backend_module, backend_function, [data, changeset, backend_config]) do
        {:cont, result} ->
          socket = notify_parent(socket, {:ok, %{result: result, data: data}})
          {:noreply, assign(socket, :submitting, false)}

        {:halt, %Ecto.Changeset{} = changeset} ->
          {:noreply, handle_invalid_submit(socket, changeset, nil)}

        {:halt, reason} ->
          {:noreply, handle_invalid_submit(socket, changeset, reason)}
      end
    else
      if changeset.valid? do
        socket = notify_parent(socket, {:ok, %{result: %{}, data: data}})
        {:noreply, assign(socket, :submitting, false)}
      else
        {:noreply, handle_invalid_submit(socket, changeset, nil)}
      end
    end
  end

  # Helpers - Data

  # Seed initial params with each question's defaultValue. Explicitly provided
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
  end

  defp merge_data(initial_params, changeset_data) do
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
    initial = recursively_convert_to_string_keys(initial_params)
    changeset = recursively_convert_to_string_keys(changeset_data)

    Map.merge(initial, changeset)
  end

  defp recursively_convert_to_string_keys(%Decimal{} = value), do: value

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

  # Render the failed changeset's errors inline and notify the parent.
  # `reason` carries a backend's non-changeset {:halt, reason} term, nil otherwise.
  defp handle_invalid_submit(socket, changeset, reason) do
    changeset = Map.put(changeset, :action, :validate)
    form = to_form(changeset, as: socket.assigns.form_name)

    socket
    |> notify_parent({:error, %{changeset: changeset, reason: reason}})
    |> assign(:changeset, changeset)
    |> assign(:form, form)
    |> assign(:submitting, false)
  end

  # Send the submit outcome to the parent LiveView when send_messages is set
  defp notify_parent(socket, outcome) do
    if socket.assigns[:send_messages] do
      send(self(), {:dynamic_form_submit, socket.assigns.id, outcome})
    end

    socket
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
      class={[
        "phx-submit-loading:opacity-75 rounded-lg bg-zinc-900 hover:bg-zinc-700 py-2 px-3",
        "text-sm font-semibold leading-6 text-white active:text-white/80",
        "disabled:opacity-50 disabled:cursor-not-allowed",
        @class
      ]}
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

      changeset = DynamicForm.Changeset.create_changeset(socket.assigns.instance, current_params)
      form = to_form(changeset, as: socket.assigns.form_name)

      {:noreply, assign(socket, changeset: changeset, form: form)}
    else
      {:noreply, socket}
    end
  end
end
