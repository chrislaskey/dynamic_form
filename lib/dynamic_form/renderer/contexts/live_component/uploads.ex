defmodule DynamicForm.Renderer.LiveComponent.Uploads do
  @moduledoc """
  LiveView upload wiring for `file` questions using direct-to-cloud uploads.

  `allow/2` registers an upload config per `file` question on the socket,
  with an external presigner (see `DynamicForm.DirectUpload`) and a progress
  callback that folds completed uploads into the form's changeset.

  Internal module — not part of the public API.
  """

  import Phoenix.Component, only: [assign: 2, to_form: 2]
  import Phoenix.LiveView, only: [allow_upload: 3]

  require Logger

  alias DynamicForm.Changeset
  alias DynamicForm.Instance.Elements

  @doc """
  Registers an upload config on the socket for every `file` question in the
  instance, configured from the question's metadata.
  """
  def allow(socket, instance) do
    file_upload_questions = Elements.list_file_questions(instance.elements)

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
        Changeset.create_changeset(socket.assigns.instance, current_params,
          custom_field_types: socket.assigns[:custom_field_types]
        )

      form = to_form(changeset, as: socket.assigns.form_name)

      {:noreply, assign(socket, changeset: changeset, form: form)}
    else
      {:noreply, socket}
    end
  end
end
