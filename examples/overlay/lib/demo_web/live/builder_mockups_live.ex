defmodule DemoWeb.BuilderMockupsLive do
  @moduledoc """
  WYSIWYG Form Builder UI Mockups

  This page showcases 5 different design approaches for the form builder interface.
  """

  use DemoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_mockup: 1)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gray-50 py-8">
        <div class="px-8">
          <div class="mb-8">
            <h1 class="text-4xl font-bold text-gray-900">Form Builder UI Mockups</h1>
            <p class="mt-2 text-lg text-gray-600">
              Exploring different approaches for the WYSIWYG form builder interface
            </p>
          </div>
          
    <!-- Mockup Selector -->
          <div class="mb-8 flex gap-2 overflow-x-auto rounded-lg bg-white p-4 shadow">
            <button
              phx-click="select_mockup"
              phx-value-mockup="1"
              class={[
                "rounded-lg px-4 py-2 font-medium transition-colors",
                if(@active_mockup == 1,
                  do: "bg-indigo-600 text-white",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                )
              ]}
            >
              Mockup 1: Sidebar + Canvas
            </button>
            <button
              phx-click="select_mockup"
              phx-value-mockup="2"
              class={[
                "rounded-lg px-4 py-2 font-medium transition-colors",
                if(@active_mockup == 2,
                  do: "bg-indigo-600 text-white",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                )
              ]}
            >
              Mockup 2: Three Columns
            </button>
            <button
              phx-click="select_mockup"
              phx-value-mockup="3"
              class={[
                "rounded-lg px-4 py-2 font-medium transition-colors",
                if(@active_mockup == 3,
                  do: "bg-indigo-600 text-white",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                )
              ]}
            >
              Mockup 3: Inline Edit
            </button>
            <button
              phx-click="select_mockup"
              phx-value-mockup="4"
              class={[
                "rounded-lg px-4 py-2 font-medium transition-colors",
                if(@active_mockup == 4,
                  do: "bg-indigo-600 text-white",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                )
              ]}
            >
              Mockup 4: Modal-Based
            </button>
            <button
              phx-click="select_mockup"
              phx-value-mockup="5"
              class={[
                "rounded-lg px-4 py-2 font-medium transition-colors",
                if(@active_mockup == 5,
                  do: "bg-indigo-600 text-white",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200"
                )
              ]}
            >
              Mockup 5: Tabs + Preview
            </button>
          </div>
          
    <!-- Mockup Content -->
          <%= case @active_mockup do %>
            <% 1 -> %>
              {render_mockup_1(assigns)}
            <% 2 -> %>
              {render_mockup_2(assigns)}
            <% 3 -> %>
              {render_mockup_3(assigns)}
            <% 4 -> %>
              {render_mockup_4(assigns)}
            <% 5 -> %>
              {render_mockup_5(assigns)}
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Mockup 1: Sidebar with Field Palette + Canvas
  defp render_mockup_1(assigns) do
    ~H"""
    <div class="rounded-lg bg-white shadow-lg overflow-hidden">
      <div class="border-b bg-gray-50 px-6 py-4">
        <h2 class="text-xl font-bold text-gray-900">Mockup 1: Sidebar + Canvas</h2>
        <p class="mt-1 text-sm text-gray-600">
          Field palette on the left, form canvas in the center, properties panel on the right
        </p>
      </div>

      <div class="flex h-[700px]">
        <!-- Left Sidebar: Field Palette -->
        <div class="w-64 border-r bg-gray-50 p-4 overflow-y-auto">
          <h3 class="mb-3 text-sm font-semibold text-gray-700 uppercase tracking-wide">
            Add Fields
          </h3>
          <div class="space-y-2">
            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 bg-white p-3 text-left hover:border-indigo-500 hover:bg-indigo-50 transition-colors">
              <div class="font-medium text-gray-900">📝 Text Input</div>
              <div class="text-xs text-gray-500">Single line text</div>
            </button>
            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 bg-white p-3 text-left hover:border-indigo-500 hover:bg-indigo-50 transition-colors">
              <div class="font-medium text-gray-900">📧 Email</div>
              <div class="text-xs text-gray-500">Email address</div>
            </button>
            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 bg-white p-3 text-left hover:border-indigo-500 hover:bg-indigo-50 transition-colors">
              <div class="font-medium text-gray-900">📄 Textarea</div>
              <div class="text-xs text-gray-500">Multi-line text</div>
            </button>
            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 bg-white p-3 text-left hover:border-indigo-500 hover:bg-indigo-50 transition-colors">
              <div class="font-medium text-gray-900">🔢 Number</div>
              <div class="text-xs text-gray-500">Numeric input</div>
            </button>
            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 bg-white p-3 text-left hover:border-indigo-500 hover:bg-indigo-50 transition-colors">
              <div class="font-medium text-gray-900">☑️ Checkbox</div>
              <div class="text-xs text-gray-500">Boolean value</div>
            </button>
            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 bg-white p-3 text-left hover:border-indigo-500 hover:bg-indigo-50 transition-colors">
              <div class="font-medium text-gray-900">📋 Select</div>
              <div class="text-xs text-gray-500">Dropdown menu</div>
            </button>
          </div>
        </div>
        
    <!-- Center: Form Canvas -->
        <div class="flex-1 p-6 overflow-y-auto">
          <div class="max-w-2xl mx-auto">
            <div class="mb-6 rounded-lg border-2 border-indigo-200 bg-indigo-50 p-4">
              <h4 class="font-semibold text-indigo-900">Contact Form</h4>
              <p class="text-sm text-indigo-700">Click fields to edit properties</p>
            </div>
            
    <!-- Field Item Example -->
            <div class="mb-4 group rounded-lg border-2 border-gray-200 bg-white p-4 hover:border-indigo-500 cursor-pointer transition-all">
              <div class="flex items-start gap-3">
                <div class="flex flex-col gap-1">
                  <button class="text-gray-400 hover:text-gray-600">↑</button>
                  <button class="text-gray-400 hover:text-gray-600">↓</button>
                </div>
                <div class="flex-1">
                  <label class="block text-sm font-medium text-gray-700">
                    Full Name <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    placeholder="John Doe"
                    disabled
                    class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50"
                  />
                  <p class="mt-1 text-xs text-gray-500">Enter your full name</p>
                </div>
                <button class="text-gray-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-opacity">
                  🗑️
                </button>
              </div>
            </div>

            <div class="mb-4 rounded-lg border-2 border-gray-200 bg-white p-4 hover:border-indigo-500 cursor-pointer transition-all group">
              <div class="flex items-start gap-3">
                <div class="flex flex-col gap-1">
                  <button class="text-gray-400 hover:text-gray-600">↑</button>
                  <button class="text-gray-400 hover:text-gray-600">↓</button>
                </div>
                <div class="flex-1">
                  <label class="block text-sm font-medium text-gray-700">
                    Email Address <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="email"
                    placeholder="john@example.com"
                    disabled
                    class="mt-1 block w-full rounded-md border-gray-300 bg-gray-50"
                  />
                </div>
                <button class="text-gray-400 hover:text-red-600 opacity-0 group-hover:opacity-100 transition-opacity">
                  🗑️
                </button>
              </div>
            </div>

            <div class="rounded-lg border-2 border-dashed border-gray-300 bg-gray-50 p-8 text-center text-gray-500">
              Drop fields here or click "Add Fields" to add more
            </div>
          </div>
        </div>
        
    <!-- Right Sidebar: Properties Panel -->
        <div class="w-80 border-l bg-gray-50 p-4 overflow-y-auto">
          <h3 class="mb-4 text-sm font-semibold text-gray-700 uppercase tracking-wide">
            Field Properties
          </h3>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Field Type</label>
              <select class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                <option>Text Input</option>
                <option>Email</option>
                <option>Textarea</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Label</label>
              <input
                type="text"
                value="Full Name"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Placeholder</label>
              <input
                type="text"
                value="John Doe"
                class="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Help Text</label>
              <textarea rows="2" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">Enter your full name</textarea>
            </div>
            <div>
              <label class="flex items-center">
                <input type="checkbox" checked class="rounded border-gray-300 text-indigo-600" />
                <span class="ml-2 text-sm text-gray-700">Required field</span>
              </label>
            </div>
            <div class="border-t pt-4">
              <h4 class="mb-2 text-sm font-semibold text-gray-700">Validations</h4>
              <button class="w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm hover:bg-gray-50">
                + Add Validation
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Mockup 2: Three Column Layout (Palette | Form List | Preview)
  defp render_mockup_2(assigns) do
    ~H"""
    <div class="rounded-lg bg-white shadow-lg overflow-hidden">
      <div class="border-b bg-gray-50 px-6 py-4">
        <h2 class="text-xl font-bold text-gray-900">Mockup 2: Three Columns</h2>
        <p class="mt-1 text-sm text-gray-600">
          Field types left, editable list center, live preview right
        </p>
      </div>

      <div class="flex h-[700px]">
        <!-- Left: Field Types -->
        <div class="w-48 border-r bg-gray-50 p-3 overflow-y-auto">
          <h3 class="mb-2 text-xs font-semibold text-gray-600 uppercase">Field Types</h3>
          <div class="space-y-1">
            <button class="w-full rounded bg-white px-3 py-2 text-left text-sm hover:bg-indigo-100">
              📝 Text
            </button>
            <button class="w-full rounded bg-white px-3 py-2 text-left text-sm hover:bg-indigo-100">
              📧 Email
            </button>
            <button class="w-full rounded bg-white px-3 py-2 text-left text-sm hover:bg-indigo-100">
              📄 Textarea
            </button>
            <button class="w-full rounded bg-white px-3 py-2 text-left text-sm hover:bg-indigo-100">
              🔢 Number
            </button>
            <button class="w-full rounded bg-white px-3 py-2 text-left text-sm hover:bg-indigo-100">
              ☑️ Checkbox
            </button>
            <button class="w-full rounded bg-white px-3 py-2 text-left text-sm hover:bg-indigo-100">
              📋 Select
            </button>
          </div>
        </div>
        
    <!-- Center: Editable Field List -->
        <div class="flex-1 p-6 overflow-y-auto bg-white">
          <div class="mb-4">
            <input
              type="text"
              value="Contact Form"
              class="text-2xl font-bold border-0 border-b-2 border-transparent hover:border-gray-300 focus:border-indigo-500 w-full"
            />
            <textarea
              rows="2"
              class="mt-2 text-sm text-gray-600 border-0 border-b border-transparent hover:border-gray-300 focus:border-indigo-500 w-full resize-none"
            >Fill out this form to contact us</textarea>
          </div>

          <div class="space-y-3">
            <!-- Expanded Field -->
            <div class="rounded-lg border-2 border-indigo-500 bg-indigo-50 p-4">
              <div class="flex items-center gap-2 mb-3">
                <button class="text-indigo-600 hover:text-indigo-800">⋮⋮</button>
                <span class="rounded bg-indigo-100 px-2 py-1 text-xs font-medium text-indigo-700">
                  TEXT
                </span>
                <input
                  type="text"
                  value="Full Name"
                  class="flex-1 rounded border-indigo-200 text-sm font-medium"
                />
                <span class="text-red-500 text-xs">*</span>
                <button class="text-red-500 hover:text-red-700">✕</button>
              </div>
              <div class="grid grid-cols-2 gap-3 text-sm">
                <div>
                  <label class="text-xs text-gray-600">Placeholder</label>
                  <input type="text" value="John Doe" class="mt-1 w-full rounded border-gray-300" />
                </div>
                <div>
                  <label class="text-xs text-gray-600">Help Text</label>
                  <input
                    type="text"
                    value="Enter your full name"
                    class="mt-1 w-full rounded border-gray-300"
                  />
                </div>
              </div>
              <div class="mt-3">
                <label class="flex items-center text-xs">
                  <input type="checkbox" checked class="rounded border-gray-300" />
                  <span class="ml-1">Required</span>
                </label>
              </div>
            </div>
            
    <!-- Collapsed Fields -->
            <div class="rounded-lg border border-gray-300 bg-white p-3 hover:border-gray-400 cursor-pointer">
              <div class="flex items-center gap-2">
                <button class="text-gray-400 hover:text-gray-600">⋮⋮</button>
                <span class="rounded bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600">
                  EMAIL
                </span>
                <span class="flex-1 text-sm font-medium">Email Address</span>
                <span class="text-red-500 text-xs">*</span>
                <button class="text-gray-400 hover:text-red-600">✕</button>
              </div>
            </div>

            <div class="rounded-lg border border-gray-300 bg-white p-3 hover:border-gray-400 cursor-pointer">
              <div class="flex items-center gap-2">
                <button class="text-gray-400 hover:text-gray-600">⋮⋮</button>
                <span class="rounded bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600">
                  SELECT
                </span>
                <span class="flex-1 text-sm font-medium">Subject</span>
                <span class="text-red-500 text-xs">*</span>
                <button class="text-gray-400 hover:text-red-600">✕</button>
              </div>
            </div>

            <button class="w-full rounded-lg border-2 border-dashed border-gray-300 p-4 text-sm text-gray-500 hover:border-indigo-500 hover:text-indigo-600">
              + Add Field
            </button>
          </div>
        </div>
        
    <!-- Right: Live Preview -->
        <div class="w-96 border-l bg-gray-50 p-6 overflow-y-auto">
          <div class="mb-3 flex items-center justify-between">
            <h3 class="text-sm font-semibold text-gray-700 uppercase">Live Preview</h3>
            <button class="rounded bg-white px-2 py-1 text-xs border hover:bg-gray-100">
              👁️ View
            </button>
          </div>
          <div class="rounded-lg border bg-white p-6 shadow-sm">
            <h2 class="text-xl font-bold text-gray-900">Contact Form</h2>
            <p class="mt-1 text-sm text-gray-600 mb-6">Fill out this form to contact us</p>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Full Name <span class="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  placeholder="John Doe"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                />
                <p class="mt-1 text-xs text-gray-500">Enter your full name</p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Email Address <span class="text-red-500">*</span>
                </label>
                <input
                  type="email"
                  placeholder="john@example.com"
                  class="mt-1 block w-full rounded-md border-gray-300 shadow-sm"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700">
                  Subject <span class="text-red-500">*</span>
                </label>
                <select class="mt-1 block w-full rounded-md border-gray-300 shadow-sm">
                  <option>Select an option...</option>
                </select>
              </div>

              <button class="rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white">
                Submit
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Mockup 3: Inline Edit (Click to Edit in Place)
  defp render_mockup_3(assigns) do
    ~H"""
    <div class="rounded-lg bg-white shadow-lg overflow-hidden">
      <div class="border-b bg-gray-50 px-6 py-4">
        <h2 class="text-xl font-bold text-gray-900">Mockup 3: Inline Edit</h2>
        <p class="mt-1 text-sm text-gray-600">
          Edit fields directly in the form preview, properties appear on click
        </p>
      </div>

      <div class="p-8 bg-gray-50 min-h-[700px]">
        <div class="mx-auto">
          <div class="rounded-lg bg-white p-8 shadow-sm">
            <!-- Form Header (Editable) -->
            <div class="mb-8 border-b pb-6">
              <input
                type="text"
                value="Contact Form"
                class="text-3xl font-bold border-0 border-b-2 border-transparent hover:border-gray-200 focus:border-indigo-500 w-full mb-2"
              />
              <textarea
                rows="2"
                class="text-gray-600 border-0 border-b border-transparent hover:border-gray-200 focus:border-indigo-500 w-full resize-none"
              >Please fill out this form to get in touch with us.</textarea>
            </div>
            
    <!-- Field with Inline Edit Panel -->
            <div class="mb-6 group">
              <div class="flex gap-4">
                <div class="flex-1 rounded-lg border-2 border-indigo-500 bg-indigo-50 p-4">
                  <label class="block text-sm font-medium text-gray-700 mb-2">
                    Full Name <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="text"
                    placeholder="John Doe"
                    disabled
                    class="block w-full rounded-md border-gray-300 bg-white"
                  />
                  <p class="mt-2 text-xs text-gray-500">Enter your full name</p>
                </div>
                
    <!-- Inline Properties Panel -->
                <div class="w-80 rounded-lg border border-indigo-200 bg-white p-4 shadow-lg">
                  <div class="flex items-center justify-between mb-4">
                    <h4 class="font-semibold text-gray-900">Edit Field</h4>
                    <div class="flex gap-1">
                      <button class="p-1 hover:bg-gray-100 rounded">↑</button>
                      <button class="p-1 hover:bg-gray-100 rounded">↓</button>
                      <button class="p-1 hover:bg-red-100 text-red-600 rounded">🗑️</button>
                    </div>
                  </div>
                  <div class="space-y-3 text-sm">
                    <div>
                      <label class="block text-xs font-medium text-gray-700 mb-1">Type</label>
                      <select class="w-full rounded border-gray-300">
                        <option>Text Input</option>
                        <option>Email</option>
                      </select>
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-gray-700 mb-1">Label</label>
                      <input type="text" value="Full Name" class="w-full rounded border-gray-300" />
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-gray-700 mb-1">
                        Placeholder
                      </label>
                      <input type="text" value="John Doe" class="w-full rounded border-gray-300" />
                    </div>
                    <label class="flex items-center">
                      <input type="checkbox" checked class="rounded border-gray-300" />
                      <span class="ml-2">Required</span>
                    </label>
                  </div>
                </div>
              </div>
            </div>
            
    <!-- Regular Fields (Click to Edit) -->
            <div class="mb-4 rounded-lg border-2 border-transparent p-4 hover:border-gray-300 hover:bg-gray-50 cursor-pointer transition-all">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Email Address <span class="text-red-500">*</span>
              </label>
              <input
                type="email"
                placeholder="john@example.com"
                disabled
                class="block w-full rounded-md border-gray-300 bg-gray-50"
              />
            </div>

            <div class="mb-4 rounded-lg border-2 border-transparent p-4 hover:border-gray-300 hover:bg-gray-50 cursor-pointer transition-all">
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Subject <span class="text-red-500">*</span>
              </label>
              <select disabled class="block w-full rounded-md border-gray-300 bg-gray-50">
                <option>Select an option...</option>
              </select>
            </div>
            
    <!-- Add Field Buttons -->
            <div class="mt-8 grid grid-cols-3 gap-3">
              <button class="rounded-lg border-2 border-dashed border-gray-300 p-4 text-sm hover:border-indigo-500 hover:bg-indigo-50">
                + Text Input
              </button>
              <button class="rounded-lg border-2 border-dashed border-gray-300 p-4 text-sm hover:border-indigo-500 hover:bg-indigo-50">
                + Email
              </button>
              <button class="rounded-lg border-2 border-dashed border-gray-300 p-4 text-sm hover:border-indigo-500 hover:bg-indigo-50">
                + Select
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Mockup 4: Modal-Based Editing
  defp render_mockup_4(assigns) do
    ~H"""
    <div class="rounded-lg bg-white shadow-lg overflow-hidden">
      <div class="border-b bg-gray-50 px-6 py-4">
        <h2 class="text-xl font-bold text-gray-900">Mockup 4: Modal-Based</h2>
        <p class="mt-1 text-sm text-gray-600">
          Simple list view with modal dialogs for editing
        </p>
      </div>

      <div class="p-8 bg-gray-50 min-h-[700px]">
        <div class="mx-auto">
          <!-- Toolbar -->
          <div class="mb-6 flex items-center justify-between rounded-lg bg-white p-4 shadow-sm">
            <div>
              <h3 class="text-lg font-bold text-gray-900">Contact Form</h3>
              <p class="text-sm text-gray-500">6 fields</p>
            </div>
            <button class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700">
              + Add Field
            </button>
          </div>
          
    <!-- Field List -->
          <div class="space-y-3">
            <div class="rounded-lg bg-white p-4 shadow-sm hover:shadow-md transition-shadow">
              <div class="flex items-center gap-4">
                <button class="text-gray-400 hover:text-gray-600">⋮⋮</button>
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="rounded bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-700">
                      TEXT
                    </span>
                    <span class="font-medium text-gray-900">Full Name</span>
                    <span class="text-red-500 text-sm">*</span>
                  </div>
                  <p class="text-sm text-gray-500">Placeholder: John Doe</p>
                  <p class="text-xs text-gray-400 mt-1">Help: Enter your full name</p>
                </div>
                <div class="flex gap-2">
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50">
                    Edit
                  </button>
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm text-gray-400 hover:bg-gray-50">
                    ↑
                  </button>
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm text-gray-400 hover:bg-gray-50">
                    ↓
                  </button>
                  <button class="rounded border border-red-300 px-3 py-1 text-sm text-red-600 hover:bg-red-50">
                    Delete
                  </button>
                </div>
              </div>
            </div>

            <div class="rounded-lg bg-white p-4 shadow-sm">
              <div class="flex items-center gap-4">
                <button class="text-gray-400 hover:text-gray-600">⋮⋮</button>
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="rounded bg-purple-100 px-2 py-0.5 text-xs font-medium text-purple-700">
                      EMAIL
                    </span>
                    <span class="font-medium text-gray-900">Email Address</span>
                    <span class="text-red-500 text-sm">*</span>
                  </div>
                  <p class="text-sm text-gray-500">Placeholder: john@example.com</p>
                </div>
                <div class="flex gap-2">
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50">
                    Edit
                  </button>
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm text-gray-400 hover:bg-gray-50">
                    ↑
                  </button>
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm text-gray-400 hover:bg-gray-50">
                    ↓
                  </button>
                  <button class="rounded border border-red-300 px-3 py-1 text-sm text-red-600 hover:bg-red-50">
                    Delete
                  </button>
                </div>
              </div>
            </div>

            <div class="rounded-lg bg-white p-4 shadow-sm">
              <div class="flex items-center gap-4">
                <button class="text-gray-400 hover:text-gray-600">⋮⋮</button>
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="rounded bg-green-100 px-2 py-0.5 text-xs font-medium text-green-700">
                      SELECT
                    </span>
                    <span class="font-medium text-gray-900">Subject</span>
                    <span class="text-red-500 text-sm">*</span>
                  </div>
                  <p class="text-sm text-gray-500">4 options</p>
                </div>
                <div class="flex gap-2">
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm hover:bg-gray-50">
                    Edit
                  </button>
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm text-gray-400 hover:bg-gray-50">
                    ↑
                  </button>
                  <button class="rounded border border-gray-300 px-3 py-1 text-sm text-gray-400 hover:bg-gray-50">
                    ↓
                  </button>
                  <button class="rounded border border-red-300 px-3 py-1 text-sm text-red-600 hover:bg-red-50">
                    Delete
                  </button>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Modal Preview (Overlay) -->
          <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[80vh] overflow-y-auto">
              <div class="border-b px-6 py-4 flex items-center justify-between">
                <h3 class="text-xl font-bold text-gray-900">Edit Field</h3>
                <button class="text-gray-400 hover:text-gray-600 text-2xl">×</button>
              </div>
              <div class="p-6 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Field Type</label>
                  <select class="w-full rounded-lg border-gray-300">
                    <option>Text Input</option>
                    <option>Email</option>
                    <option>Textarea</option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Label</label>
                  <input type="text" value="Full Name" class="w-full rounded-lg border-gray-300" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Placeholder</label>
                  <input type="text" value="John Doe" class="w-full rounded-lg border-gray-300" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Help Text</label>
                  <textarea rows="2" class="w-full rounded-lg border-gray-300">Enter your full name</textarea>
                </div>
                <div>
                  <label class="flex items-center">
                    <input type="checkbox" checked class="rounded border-gray-300 text-indigo-600" />
                    <span class="ml-2 text-sm font-medium text-gray-700">Required field</span>
                  </label>
                </div>
              </div>
              <div class="border-t px-6 py-4 flex gap-3 justify-end">
                <button class="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium hover:bg-gray-50">
                  Cancel
                </button>
                <button class="rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700">
                  Save Changes
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Mockup 5: Tabs with Split Preview
  defp render_mockup_5(assigns) do
    ~H"""
    <div class="rounded-lg bg-white shadow-lg overflow-hidden">
      <div class="border-b bg-gray-50 px-6 py-4">
        <h2 class="text-xl font-bold text-gray-900">Mockup 5: Tabs + Preview</h2>
        <p class="mt-1 text-sm text-gray-600">
          Tabbed editing interface with split screen preview
        </p>
      </div>

      <div class="flex h-[700px]">
        <!-- Left: Tabbed Editor -->
        <div class="flex-1 flex flex-col">
          <!-- Tabs -->
          <div class="border-b bg-gray-50 px-4 flex gap-1">
            <button class="px-4 py-3 text-sm font-medium border-b-2 border-indigo-600 text-indigo-600">
              Fields
            </button>
            <button class="px-4 py-3 text-sm font-medium text-gray-500 hover:text-gray-700">
              Settings
            </button>
            <button class="px-4 py-3 text-sm font-medium text-gray-500 hover:text-gray-700">
              Validations
            </button>
            <button class="px-4 py-3 text-sm font-medium text-gray-500 hover:text-gray-700">
              Backend
            </button>
          </div>
          
    <!-- Tab Content -->
          <div class="flex-1 p-6 overflow-y-auto bg-white">
            <div class="mb-4">
              <button class="w-full rounded-lg bg-indigo-600 px-4 py-3 text-sm font-semibold text-white hover:bg-indigo-700">
                + Add New Field
              </button>
            </div>
            
    <!-- Accordion-style Fields -->
            <div class="space-y-3">
              <!-- Expanded Field -->
              <div class="rounded-lg border-2 border-indigo-500 overflow-hidden">
                <button class="w-full bg-indigo-50 px-4 py-3 flex items-center justify-between text-left">
                  <div class="flex items-center gap-3">
                    <span class="text-indigo-600">▼</span>
                    <span class="rounded bg-indigo-100 px-2 py-1 text-xs font-medium text-indigo-700">
                      TEXT
                    </span>
                    <span class="font-medium text-gray-900">Full Name</span>
                    <span class="text-red-500">*</span>
                  </div>
                  <div class="flex gap-2">
                    <button class="text-gray-500 hover:text-gray-700 px-2">↑</button>
                    <button class="text-gray-500 hover:text-gray-700 px-2">↓</button>
                    <button class="text-red-500 hover:text-red-700 px-2">×</button>
                  </div>
                </button>
                <div class="bg-white p-4 space-y-3">
                  <div class="grid grid-cols-2 gap-3">
                    <div>
                      <label class="block text-xs font-medium text-gray-700 mb-1">Type</label>
                      <select class="w-full rounded border-gray-300 text-sm">
                        <option>Text Input</option>
                        <option>Email</option>
                      </select>
                    </div>
                    <div>
                      <label class="block text-xs font-medium text-gray-700 mb-1">Label</label>
                      <input
                        type="text"
                        value="Full Name"
                        class="w-full rounded border-gray-300 text-sm"
                      />
                    </div>
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Placeholder</label>
                    <input
                      type="text"
                      value="John Doe"
                      class="w-full rounded border-gray-300 text-sm"
                    />
                  </div>
                  <div>
                    <label class="block text-xs font-medium text-gray-700 mb-1">Help Text</label>
                    <input
                      type="text"
                      value="Enter your full name"
                      class="w-full rounded border-gray-300 text-sm"
                    />
                  </div>
                  <div class="flex items-center gap-4">
                    <label class="flex items-center">
                      <input type="checkbox" checked class="rounded border-gray-300 text-indigo-600" />
                      <span class="ml-2 text-sm">Required</span>
                    </label>
                  </div>
                  <div class="border-t pt-3">
                    <div class="flex items-center justify-between mb-2">
                      <span class="text-xs font-medium text-gray-700">Validations</span>
                      <button class="text-xs text-indigo-600 hover:text-indigo-700">+ Add</button>
                    </div>
                    <div class="text-xs text-gray-500 bg-gray-50 rounded p-2">
                      Min length: 2 characters
                    </div>
                  </div>
                </div>
              </div>
              
    <!-- Collapsed Fields -->
              <div class="rounded-lg border border-gray-300 overflow-hidden hover:border-gray-400">
                <button class="w-full bg-white px-4 py-3 flex items-center justify-between text-left hover:bg-gray-50">
                  <div class="flex items-center gap-3">
                    <span class="text-gray-400">▶</span>
                    <span class="rounded bg-purple-100 px-2 py-1 text-xs font-medium text-purple-700">
                      EMAIL
                    </span>
                    <span class="font-medium text-gray-900">Email Address</span>
                    <span class="text-red-500">*</span>
                  </div>
                  <div class="flex gap-2">
                    <button class="text-gray-400 hover:text-gray-600 px-2">↑</button>
                    <button class="text-gray-400 hover:text-gray-600 px-2">↓</button>
                    <button class="text-red-400 hover:text-red-600 px-2">×</button>
                  </div>
                </button>
              </div>

              <div class="rounded-lg border border-gray-300 overflow-hidden hover:border-gray-400">
                <button class="w-full bg-white px-4 py-3 flex items-center justify-between text-left hover:bg-gray-50">
                  <div class="flex items-center gap-3">
                    <span class="text-gray-400">▶</span>
                    <span class="rounded bg-green-100 px-2 py-1 text-xs font-medium text-green-700">
                      SELECT
                    </span>
                    <span class="font-medium text-gray-900">Subject</span>
                    <span class="text-red-500">*</span>
                  </div>
                  <div class="flex gap-2">
                    <button class="text-gray-400 hover:text-gray-600 px-2">↑</button>
                    <button class="text-gray-400 hover:text-gray-600 px-2">↓</button>
                    <button class="text-red-400 hover:text-red-600 px-2">×</button>
                  </div>
                </button>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Right: Live Preview -->
        <div class="w-1/2 border-l bg-gray-100 p-6 overflow-y-auto">
          <div class="mb-3 flex items-center justify-between">
            <h3 class="text-sm font-semibold text-gray-700 uppercase">Preview</h3>
            <div class="flex gap-2">
              <button class="rounded border bg-white px-3 py-1 text-xs hover:bg-gray-50">
                Desktop
              </button>
              <button class="rounded border border-gray-300 px-3 py-1 text-xs hover:bg-gray-50">
                Mobile
              </button>
            </div>
          </div>
          <div class="rounded-lg bg-white p-8 shadow-lg">
            <h2 class="text-2xl font-bold text-gray-900">Contact Form</h2>
            <p class="mt-2 text-sm text-gray-600 mb-8">
              Please fill out this form to get in touch with us.
            </p>

            <div class="space-y-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Full Name <span class="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  placeholder="John Doe"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                />
                <p class="mt-1 text-xs text-gray-500">Enter your full name</p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Email Address <span class="text-red-500">*</span>
                </label>
                <input
                  type="email"
                  placeholder="john@example.com"
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Subject <span class="text-red-500">*</span>
                </label>
                <select class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
                  <option>Select an option...</option>
                  <option>General Inquiry</option>
                  <option>Support</option>
                </select>
              </div>

              <button class="rounded-md bg-indigo-600 px-6 py-3 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500">
                Submit Form
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_mockup", %{"mockup" => mockup}, socket) do
    {:noreply, assign(socket, :active_mockup, String.to_integer(mockup))}
  end
end
