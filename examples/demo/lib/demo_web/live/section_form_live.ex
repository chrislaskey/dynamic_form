defmodule DemoWeb.SectionFormLive do
  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  @impl true
  def mount(_params, _session, socket) do
    # Get section form instance
    form_instance = Demo.FormInstances.section_form()

    # Encode to JSON for demonstration
    json_string = Jason.encode!(form_instance)

    {:ok,
     socket
     |> assign(:form_instance, form_instance)
     |> assign(:json_string, json_string)
     |> assign(:json_pretty, Jason.encode!(form_instance, pretty: true))
     |> assign(:use_json, true)
     |> assign(:submitted_data, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Section Element Demo</h1>
          <p class="mt-2 text-gray-600">
            This form demonstrates the new Section element for organizing form contents.
          </p>
          <p class="mt-2 text-sm text-indigo-600">
            <strong>New:</strong>
            This form uses an external submit button (shown below) instead of a button inside the form.
          </p>
        </div>

        <%!-- JSON vs Struct Toggle --%>
        <div class="mb-6 rounded-lg bg-indigo-50 border border-indigo-200 p-4">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-semibold text-indigo-900">Instance Format</h3>
              <p class="mt-1 text-xs text-indigo-700">
                Toggle between struct and JSON string to see both formats work identically
              </p>
            </div>
            <button
              phx-click="toggle_format"
              class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
            >
              {if @use_json, do: "📋 Using JSON String", else: "🏗️ Using Struct"}
            </button>
          </div>
          <div class="mt-3 text-xs text-indigo-800 font-mono bg-indigo-100 p-2 rounded">
            {if @use_json, do: "json", else: "instance"}=&lbrace;{if @use_json,
              do: "@json_string",
              else: "@form_instance"}&rbrace;
          </div>
        </div>

        <.definition
          title={"Form Definition (#{if @use_json, do: "JSON", else: "Instance structs"})"}
          subtitle="The toggle above switches which format is passed to the renderer — this block follows it"
          code={if @use_json, do: @json_pretty, else: inspect(@form_instance, pretty: true)}
        />

        <%!-- External submit button at the top --%>
        <div class="mb-6 flex justify-end">
          <DynamicForm.submit_button form="section-form-form" class="shadow-lg">
            💾 Save Profile
          </DynamicForm.submit_button>
        </div>

        <div class="rounded-lg bg-gray-50 shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form
            id="section-form"
            instance={if !@use_json, do: @form_instance}
            json={if @use_json, do: @json_string}
            hide_submit
            send_messages
            submit_text="Save Profile"
            validation_summary="detailed"
          />
        </div>

        <%= if @submitted_data do %>
          <div class="mt-8 rounded-lg bg-green-50 p-6">
            <h3 class="text-lg font-semibold text-green-900 mb-4">✓ Profile Saved Successfully!</h3>
            <div class="text-sm text-green-800">
              <p class="font-semibold mb-2">Submitted Data:</p>
              <pre class="bg-green-100 p-4 rounded overflow-x-auto"><%= inspect(@submitted_data, pretty: true) %></pre>
            </div>
          </div>
        <% end %>

        <div class="mt-8 rounded-lg bg-purple-50 p-6">
          <h3 class="text-lg font-semibold text-purple-900 mb-4">
            🎉 New: JSON Encoding/Decoding
          </h3>
          <div class="text-sm text-purple-800 space-y-3">
            <p>
              <strong>DynamicForm now supports JSON!</strong>
              You can encode form instances to JSON and decode them back to structs.
              This makes it easy to:
            </p>
            <ul class="list-disc list-inside ml-4">
              <li>Store form configurations in a database as JSON</li>
              <li>Send form configurations over the wire (API responses)</li>
              <li>Serialize/deserialize form configurations for caching</li>
              <li>Create forms from JSON configuration files</li>
            </ul>
            <p class="mt-2">
              <strong>Try it:</strong>
              Use the toggle button above to switch between struct and JSON formats. The form works
              identically with both!
            </p>
          </div>
        </div>

        <div class="mt-8 rounded-lg bg-amber-50 p-6">
          <h3 class="text-lg font-semibold text-amber-900 mb-4">☁️ Direct Upload Feature</h3>
          <div class="text-sm text-amber-800 space-y-3">
            <div>
              <strong>What is Direct Upload?</strong>
              <p class="mt-1">
                The direct_upload field type enables file uploads directly to cloud storage (like Google Cloud Storage or AWS S3)
                using presigned URLs, bypassing your application server. This improves performance and scalability for file uploads.
              </p>
            </div>

            <div>
              <strong>Features:</strong>
              <ul class="list-disc list-inside ml-4 mt-1">
                <li>Upload files directly to cloud storage from the browser</li>
                <li>Progress tracking for each file</li>
                <li>Multiple file support with drag & drop</li>
                <li>File type and size validation</li>
                <li>Configurable max files and file size limits</li>
                <li>Uploaded files metadata stored in form data</li>
              </ul>
            </div>

            <div>
              <strong>Try it:</strong>
              <p class="mt-1">
                Scroll to the "Profile Documents" section below to see the direct_upload field in action.
                This example uses a mock presigner (Demo.MockUrlPresigner) for demonstration purposes.
                In a real application, you would implement a presigner that generates actual presigned URLs
                for your cloud storage provider.
              </p>
            </div>
          </div>
        </div>

        <div class="mt-8 rounded-lg bg-blue-50 p-6">
          <h3 class="text-lg font-semibold text-blue-900 mb-4">📦 Section Features</h3>
          <div class="text-sm text-blue-800 space-y-3">
            <div>
              <strong>What is a Section?</strong>
              <p class="mt-1">
                A Section is a visual container element that groups related form content together.
                It renders as a card-like block with a border, rounded corners, and padding.
              </p>
            </div>

            <div>
              <strong>Section Capabilities:</strong>
              <ul class="list-disc list-inside ml-4 mt-1">
                <li>Optional title displayed at the top</li>
                <li>Can contain fields, groups, and other elements</li>
                <li>Supports nested sections (section within a section)</li>
                <li>Custom CSS classes via metadata</li>
                <li>Conditional visibility (show/hide based on field values)</li>
              </ul>
            </div>

            <div>
              <strong>✨ External Submit Button:</strong>
              <p class="mt-1">
                This form demonstrates the new external submit button feature. The submit button
                at the top of the page is connected to the form using the HTML <code>form</code>
                attribute, allowing you to place submit buttons anywhere on the page - not just
                inside the form. Perfect for sticky footers, modal headers, or complex layouts!
              </p>
            </div>

            <div>
              <strong>Sections in this Form:</strong>
              <ul class="list-disc list-inside ml-4 mt-1">
                <li><strong>Personal Information</strong> - Contains name group and email field</li>
                <li><strong>Address</strong> - Contains street and city/state/zip group</li>
                <li>
                  <strong>Preferences</strong>
                  - Contains newsletter checkbox with conditional frequency field
                </li>
                <li>
                  <strong>Additional Information</strong> - Contains bio field and a nested
                  "Social Media Links" section
                </li>
                <li>
                  <strong>Profile Documents</strong> - Contains a direct_upload field for file uploads
                </li>
              </ul>
            </div>

            <div>
              <strong>Section vs Group:</strong>
              <p class="mt-1">
                While both can contain multiple items, Sections are for larger visual blocks (like
                card containers), while Groups are for layout arrangements (like horizontal or grid layouts).
                Sections can contain Groups, and vice versa.
              </p>
            </div>
          </div>
        </div>

        <div class="mt-8 rounded-lg bg-gray-50 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Code Examples</h3>
          <div class="text-sm text-gray-800 space-y-4">
            <div>
              <p class="mb-2 font-semibold">✨ Using JSON with LiveComponent (New Feature!):</p>
              <pre class="bg-gray-100 p-4 rounded overflow-x-auto text-xs font-mono"><code>
              &lt;!-- You can now pass JSON strings directly! --&gt;
              &lt;.live_component
                module=&lbrace;DynamicForm.RendererLive&rbrace;
                id="section-form"
                instance=&lbrace;@json_string&rbrace;  &lt;!-- JSON string --&gt;
                send_messages=&lbrace;true&rbrace;
              /&gt;

              &lt;!-- Or use a map --&gt;
              &lt;.live_component
                module=&lbrace;DynamicForm.RendererLive&rbrace;
                id="section-form"
                instance=&lbrace;@instance_map&rbrace;  &lt;!-- Map from Jason.decode! --&gt;
                send_messages=&lbrace;true&rbrace;
              /&gt;

              &lt;!-- Or the original struct format --&gt;
              &lt;.live_component
                module=&lbrace;DynamicForm.RendererLive&rbrace;
                id="section-form"
                instance=&lbrace;@form_instance&rbrace;  &lt;!-- Instance struct --&gt;
                send_messages=&lbrace;true&rbrace;
              /&gt;
            </code></pre>
            </div>

            <div>
              <p class="mb-2 font-semibold">Encoding and Decoding Forms:</p>
              <pre class="bg-gray-100 p-4 rounded overflow-x-auto text-xs font-mono"><code>
              # In your LiveView mount/3
              def mount(_params, _session, socket) do
                # Create or load your form instance
                form_instance = Demo.FormInstances.section_form()

                # Encode to JSON string
                json_string = Jason.encode!(form_instance)

                # Later, decode back to struct
                decoded_instance = DynamicForm.Instance.decode!(json_string)

                # Or decode from a map
                map = Jason.decode!(json_string)
                decoded_instance = DynamicForm.Instance.decode!(map)

                &lbrace;:ok, assign(socket, form_instance: form_instance)&rbrace;
              end
            </code></pre>
            </div>

            <div>
              <p class="mb-2 font-semibold">Using an External Submit Button:</p>
              <pre class="bg-gray-100 p-4 rounded overflow-x-auto text-xs font-mono"><code>
              &lt;!-- External submit button anywhere on the page --&gt;
              &lt;!-- Note: form ID is "&lbrace;id&rbrace;-form", so "section-form" becomes "section-form-form" --&gt;
              &lt;DynamicForm.submit_button form="section-form-form"&gt;
                Save Profile
              &lt;/DynamicForm.submit_button&gt;

              &lt;!-- LiveComponent with hide_submit set to true --&gt;
              &lt;.live_component
                module=&lbrace;DynamicForm.RendererLive&rbrace;
                id="section-form"
                instance=&lbrace;@form_instance&rbrace;
                hide_submit=&lbrace;true&rbrace;
                send_messages=&lbrace;true&rbrace;
              /&gt;
            </code></pre>
            </div>

            <div>
              <p class="mb-2 font-semibold">Example of defining a panel in your form instance:</p>
              <pre class="bg-gray-100 p-4 rounded overflow-x-auto text-xs font-mono"><code>
              &#37;Instance.Element&lbrace;
                name: "personal-panel",
                type: "panel",
                title: "Personal Information",
                elements: [
                  &#37;Instance.Question&lbrace;
                    name: "first_name",
                    type: "text",
                    title: "First Name",
                    isRequired: true
                  &rbrace;,
                  &#37;Instance.Question&lbrace;
                    name: "email",
                    type: "text",
                    inputType: "email",
                    title: "Email",
                    isRequired: true
                  &rbrace;
                ]
              &rbrace;
            </code></pre>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Handle toggle between struct and JSON
  @impl true
  def handle_event("toggle_format", _params, socket) do
    {:noreply, assign(socket, :use_json, !socket.assigns.use_json)}
  end

  # Handle messages from RendererLive component
  @impl true
  def handle_info({:dynamic_form_success, _id, result}, socket) do
    message = Map.get(result, :message, "Profile saved successfully!")

    {:noreply,
     socket
     |> assign(:submitted_data, result.data)
     |> put_flash(:info, message)}
  end

  @impl true
  def handle_info({:dynamic_form_error, _id, error}, socket) do
    message = Map.get(error, :message, "Failed to save profile")

    {:noreply,
     socket
     |> put_flash(:error, message)}
  end
end
