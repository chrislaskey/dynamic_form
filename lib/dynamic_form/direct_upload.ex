defmodule DynamicForm.DirectUpload do
  @moduledoc """
  A LiveView component for handling direct-to-storage file uploads in dynamic forms.

  This component enables file uploads directly to cloud storage (e.g., Google Cloud Storage)
  using presigned URLs, similar to the pattern used in DirectorWeb licensing flows.

  ## Configuration

  The component requires a presigner callback function that generates presigned URLs
  for uploading files to cloud storage. This is configured via the field's metadata.

  ## Question Configuration

  Add a `file` question to your form instance:

      %DynamicForm.Instance.Question{
        name: "documents",
        type: "file",
        title: "Upload Documents",
        description: "Upload supporting documents (max 10MB per file)",
        isRequired: true,
        metadata: %{
          "max_entries" => 3,
          "max_file_size" => 10_000_000,
          "accept" => :any,  # or ["image/*", ".pdf", ".doc", ".docx"]
          "presigner" => %{
            "module" => "MyApp.UrlPresigner",
            "function" => "sign"
          },
          "bucket" => "my-bucket",
          "object_name_prefix" => "uploads/"
        }
      }

  ## Presigner Callback

  The presigner function should accept a filename and context map, and return a presigned URL:

      def sign(filename, context) do
        bucket = context.bucket
        object_name = "\#{context.prefix}\#{filename}"
        CoreData.Clients.UrlPresigner.sign(bucket, object_name)
      end

  ## Uploaded Files Data Structure

  Uploaded files are stored in the changeset as a list of maps:

      [
        %{
          "filename" => "document.pdf",
          "cloud_bucket" => "my-bucket",
          "cloud_path" => "uploads/document.pdf",
          "cloud_provider" => "gcp",
          "uploaded_on" => "10/28/2025"
        }
      ]

  ## Events

  The component sends these events to the parent LiveView:

  - `:uploads_not_ready` - When upload starts or file is deleted (and no files remain)
  - `:uploads_ready` - When all uploads complete or at least one file exists
  """

  use Phoenix.LiveComponent

  require Logger

  @impl true
  def update(assigns, socket) do
    field = assigns.field
    field_atom = String.to_atom(field.name)
    upload_name = String.to_atom("upload_#{field.name}")

    # Get existing uploaded files from form data
    uploaded_files = Phoenix.HTML.Form.input_value(assigns.form, field_atom) || []

    # Get upload config from parent (RendererLive)
    uploads = Map.get(assigns, :uploads, %{})
    upload_config = Map.get(uploads, upload_name)

    # Store parent component ID for sending updates
    parent_id = Map.get(assigns, :parent_id)

    socket =
      socket
      |> assign(:field, field)
      |> assign(:form, assigns.form)
      |> assign(:disabled, assigns.disabled)
      |> assign(:field_atom, field_atom)
      |> assign(:uploaded_files, uploaded_files)
      |> assign(:upload_name, upload_name)
      |> assign(:upload_config, upload_config)
      |> assign(:parent_id, parent_id)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block text-sm font-medium leading-6 text-zinc-900">
        <%= @field.title || String.capitalize(@field.name) %>
        <%= if @field.isRequired do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <%= if @field.description do %>
        <p class="mt-1 text-sm text-gray-500"><%= @field.description %></p>
      <% end %>

      <%= if @upload_config do %>
        <div class="mt-2 border rounded-lg shadow-sm">
          <div phx-drop-target={@upload_config.ref} class={if @disabled, do: "opacity-50 pointer-events-none"}>
            <!-- Upload Button / Drop Zone -->
            <div :if={length(@uploaded_files) == 0} class="h-32 flex justify-center items-center border-2 border-dashed border-gray-300 rounded-lg hover:border-gray-400">
              <.upload_button upload={@upload_config} />
            </div>

            <!-- File List Header -->
            <div :if={length(@uploaded_files) > 0}>
              <div class="border-b px-4 py-3 flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <span class="text-sm font-semibold"><%= @field.title || "Files" %></span>
                </div>
                <.upload_button upload={@upload_config} />
              </div>

            <!-- File List -->
            <div class="divide-y">
              <div
                :for={{file, index} <- Enum.with_index(@uploaded_files)}
                class="flex items-center px-4 py-3 hover:bg-gray-50"
                id={"uploaded-file-#{@field.name}-#{index}"}
              >
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-blue-900 truncate">
                    <%= file["filename"] %>
                  </p>
                  <p class="text-xs text-gray-500">
                    Uploaded <%= file["uploaded_on"] %>
                  </p>
                </div>
                <button
                  type="button"
                  phx-click="delete-file"
                  phx-value-index={index}
                  phx-target={@myself}
                  disabled={@disabled}
                  class="ml-4 text-gray-400 hover:text-red-600 disabled:opacity-50 disabled:cursor-not-allowed"
                  aria-label="Delete file"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>
          </div>

          <!-- Upload Progress -->
          <div
            :for={entry <- @upload_config.entries}
            class="px-4 py-3 border-t flex items-center gap-3"
            :if={entry.progress && entry.progress < 100}
          >
            <div class="flex-1">
              <div class="flex items-center justify-between mb-1">
                <span class="text-sm text-gray-700"><%= entry.client_name %></span>
                <span class="text-sm text-gray-500"><%= entry.progress %>%</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div class="bg-blue-600 h-2 rounded-full transition-all" style={"width: #{entry.progress}%"}></div>
              </div>
            </div>
            <button
              type="button"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
              phx-target={@myself}
              class="text-gray-400 hover:text-red-600"
              aria-label="Cancel upload"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Upload Errors -->
          <div :for={err <- upload_errors(@upload_config)} class="px-4 py-3 bg-red-50 border-t border-red-200">
            <p class="text-sm text-red-800"><%= error_to_string(err) %></p>
          </div>
        </div>
      </div>
      <% else %>
        <div class="mt-2 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
          <p class="text-sm text-yellow-800">Upload configuration not found. Make sure direct_upload fields are properly configured.</p>
        </div>
      <% end %>

      <!-- Hidden input to store uploaded files data -->
      <input
        type="hidden"
        name={"#{@form.name}[#{@field.name}]"}
        value={Jason.encode!(@uploaded_files)}
      />
    </div>
    """
  end

  defp upload_button(assigns) do
    ~H"""
    <label class="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold rounded-lg transition-colors bg-blue-600 text-white hover:bg-blue-700 cursor-pointer">
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
      </svg>
      <span>Upload Files</span>
      <.live_file_input upload={@upload} class="hidden" />
    </label>
    """
  end

  @impl true
  def handle_event("delete-file", %{"index" => index}, socket) do
    index = String.to_integer(index)
    uploaded_files = socket.assigns.uploaded_files

    # Remove file at index
    {deleted_file, remaining_files} = List.pop_at(uploaded_files, index)

    # TODO: Optionally delete from cloud storage via callback

    if deleted_file do
      Logger.info("File deleted: #{deleted_file["filename"]}")
    end

    # Send update to parent component
    if socket.assigns[:parent_id] do
      send_update(DynamicForm.RendererLive,
        id: socket.assigns.parent_id,
        action: :delete_file,
        field_name: socket.assigns.field.name,
        remaining_files: remaining_files
      )
    end

    {:noreply, assign(socket, uploaded_files: remaining_files)}
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    # Send update to parent component
    if socket.assigns[:parent_id] do
      send_update(DynamicForm.RendererLive,
        id: socket.assigns.parent_id,
        action: :cancel_upload,
        upload_name: socket.assigns.upload_name,
        ref: ref
      )
    end

    {:noreply, socket}
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
