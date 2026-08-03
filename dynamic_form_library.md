# DynamicForm Library

> **Note (2026-07):** This is the original design document and predates the
> migration to SurveyJS-compatible JSON format. Code examples below use the
> old bespoke format (`Instance.Field`, `visible_when`, `items`, ...). For the
> current format see `guides/surveyjs.md` and the module docs in
> `lib/dynamic_form/`.

A Phoenix LiveView library for creating dynamic forms through a WYSIWYG interface that leverages Ecto changesets and Phoenix CoreComponents.

## Overview

The DynamicForm library enables users to build forms dynamically through a visual interface, then render those forms using standard Phoenix LiveView patterns. The system consists of three main components:

1. **WYSIWYG Form Builder** - Visual interface for creating forms
2. **DynamicForm.Instance** - Configuration struct that defines form structure
3. **Dynamic Form Renderer** - Renders forms using Phoenix CoreComponents and Ecto changesets

## Articles / References

- https://fly.io/phoenix-files/liveview-drag-and-drop/
- https://fly.io/phoenix-files/dynamic-forms-with-streams/
- https://github.com/chrismccord/todo_trek

## Architecture

### Core Components

```
DynamicForm
├── Behaviour (defines callbacks for implementers)
├── Instance (configuration struct)
├── Builder (WYSIWYG LiveView component)
├── Renderer (form rendering component)
├── Changeset (utilities for dynamic changeset creation)
└── Validation (custom validation types)
```

### Data Flow

```
User Interaction (WYSIWYG) 
    ↓
DynamicForm.Instance (config)
    ↓
Dynamic Ecto.Changeset
    ↓
Phoenix CoreComponents (rendered form)
```

## Behaviour Definitions

### DynamicForm Behaviour

Implementing modules must define callbacks that provide configuration for the WYSIWYG builder:

```elixir
defmodule MyApp.CustomFormBehaviour do
  @behaviour DynamicForm

  @impl DynamicForm
  def available_form_fields do
    [
      %{type: :string, label: "Text Input", icon: "text"},
      %{type: :email, label: "Email", icon: "envelope"},
      %{type: :decimal, label: "Number", icon: "calculator"},
      %{type: :boolean, label: "Checkbox", icon: "check-square"},
      %{type: :select, label: "Dropdown", icon: "chevron-down"},
      %{type: :textarea, label: "Text Area", icon: "document-text"},
      %{type: :direct_upload, label: "File Upload", icon: "cloud-upload"}
    ]
  end

  @impl DynamicForm
  def available_backends do
    [
      %{
        module: MyApp.EmailBackend,
        name: "Email Submission",
        description: "Send form responses via email",
        icon: "envelope",
        config_fields: [
          %{name: :recipient_email, type: :email, label: "Recipient Email", required: true},
          %{name: :subject, type: :string, label: "Email Subject", required: true}
        ]
      },
      %{
        module: MyApp.DatabaseBackend,
        name: "Database Storage",
        description: "Save responses to database",
        icon: "database",
        config_fields: [
          %{name: :table_name, type: :string, label: "Table Name", required: true}
        ]
      },
      %{
        module: MyApp.WebhookBackend,
        name: "Webhook",
        description: "Send to external API endpoint",
        icon: "globe",
        config_fields: [
          %{name: :webhook_url, type: :string, label: "Webhook URL", required: true},
          %{name: :auth_token, type: :string, label: "Auth Token", required: false}
        ]
      }
    ]
  end

  @impl DynamicForm
  def select_options(field_name) do
    # Return options based on field name or type
    case field_name do
      :category -> [
        {"Fitness", "fitness"},
        {"Nutrition", "nutrition"},
        {"Recovery", "recovery"}
      ]
      _ -> []
    end
  end

  @impl DynamicForm
  def validation_rules do
    [
      %{type: :required, label: "Required Field"},
      %{type: :min_length, label: "Minimum Length", has_value: true},
      %{type: :max_length, label: "Maximum Length", has_value: true},
      %{type: :email_format, label: "Email Format"},
      %{type: :numeric_range, label: "Numeric Range", has_min_max: true}
    ]
  end

  @impl DynamicForm
  def custom_validators do
    %{
      email_format: &validate_email_format/3,
      numeric_range: &validate_numeric_range/3
    }
  end
end
```

### DynamicForm.Backend Behaviour

Backend modules handle form submission. Each backend implements how to process the form data.

**Important**: Backend functions are called on every form submission, regardless of validation state. This gives the application full control over the changeset and form processing.

The backend function signature is:

```elixir
def submit(data, changeset, config)
```

Where:
- `data` - The form data (result of `Ecto.Changeset.apply_changes/1`)
- `changeset` - The Ecto.Changeset (may be valid or invalid)
- `config` - Keyword list of backend configuration

The function must return:
- `{:cont, result}` - Continue with success (result typically contains `:message` and `:data`)
- `{:halt, changeset}` - Halt with validation errors to display on the form
- `{:halt, error}` - Halt with a general error

```elixir
defmodule MyApp.EmailBackend do
  @behaviour DynamicForm.Backend

  @impl DynamicForm.Backend
  def submit(data, changeset, config) do
    recipient_email = Keyword.fetch!(config, :recipient_email)
    subject = Keyword.fetch!(config, :subject)

    # Check if built-in validations passed
    if not changeset.valid? do
      {:halt, changeset}
    else
      case send_email(recipient_email, subject, data) do
        {:ok, _result} ->
          {:cont, %{message: gettext("Form submitted successfully via email")}}
        {:error, reason} ->
          {:halt, %{message: gettext("Failed to send email: %{reason}", reason: reason)}}
      end
    end
  end

  @impl DynamicForm.Backend
  def validate_config(config) do
    required_keys = [:recipient_email, :subject]

    case Enum.find(required_keys, &is_nil(config[&1])) do
      nil -> :ok
      missing_key -> {:error, gettext("Missing required config: %{key}", key: missing_key)}
    end
  end

  defp send_email(recipient, subject, form_data) do
    # Implementation using your email service (Swoosh, etc.)
    # Format form_data into email body
    body = format_form_data_as_email(form_data)

    # Send email logic here
    {:ok, "email_sent"}
  end

  defp format_form_data_as_email(form_data) do
    form_data
    |> Enum.map(fn {key, value} -> "#{humanize_key(key)}: #{value}" end)
    |> Enum.join("\n")
  end

  defp humanize_key(key) do
    key |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end
end

defmodule MyApp.DatabaseBackend do
  @behaviour DynamicForm.Backend

  @impl DynamicForm.Backend
  def submit(data, changeset, config) do
    table_name = Keyword.fetch!(config, :table_name)

    # Check if built-in validations passed
    if not changeset.valid? do
      {:halt, changeset}
    else
      case save_to_database(table_name, data) do
        {:ok, record} ->
          {:cont, %{message: gettext("Form data saved successfully"), record_id: record.id}}
        {:error, reason} ->
          {:halt, %{message: gettext("Failed to save: %{reason}", reason: reason)}}
      end
    end
  end

  @impl DynamicForm.Backend
  def validate_config(config) do
    case config[:table_name] do
      nil -> {:error, gettext("Missing required config: table_name")}
      table when is_binary(table) -> :ok
      _ -> {:error, gettext("table_name must be a string")}
    end
  end

  defp save_to_database(table_name, form_data) do
    # Implementation to save to your database
    # This would typically use Ecto to insert into a dynamic table
    # or a generic form_responses table
    {:ok, %{id: Ecto.UUID.generate()}}
  end
end
```

## DynamicForm.Instance Struct

The configuration struct that defines the complete form structure, including backend configuration:

```elixir
defmodule DynamicForm.Instance do
  @enforce_keys [:id, :name, :fields, :backend]
  defstruct [
    :id,
    :name,
    :description,
    :fields,
    :backend,
    :metadata,
    inserted_at: nil,
    updated_at: nil
  ]

  defmodule Field do
    @enforce_keys [:id, :name, :type]
    defstruct [
      :id,
      :name,
      :type,
      :label,
      :placeholder,
      :help_text,
      :default_value,
      :options,        # For select fields
      :validations,    # List of validation rules
      :position,       # Display order
      :required,       # Boolean
      :metadata        # Custom field metadata
    ]
  end

  defmodule Backend do
    @enforce_keys [:module, :config]
    defstruct [
      :module,         # Backend module (e.g., MyApp.EmailBackend)
      :config,         # Backend-specific configuration
      :name,           # Display name for the backend
      :description     # Description of what this backend does
    ]
  end

  defmodule Validation do
    @enforce_keys [:type]
    defstruct [
      :type,
      :value,     # For validations that need a value (min_length: 5)
      :min,       # For range validations
      :max,       # For range validations
      :message    # Custom error message
    ]
  end
end
```

## WYSIWYG Builder Component

A LiveView component that provides drag-and-drop form building:

### Features
- **Field Palette** - Available field types from behaviour
- **Form Canvas** - Drag-and-drop area for building forms
- **Field Configuration** - Edit properties of selected fields
- **Form Preview** - Live preview of the form being built
- **Validation Setup** - Configure field validation rules

### Component Structure

```elixir
defmodule DynamicForm.Builder do
  use Phoenix.LiveComponent
  
  # Props
  attr :behaviour_module, :atom, required: true
  attr :instance, DynamicForm.Instance, default: nil
  attr :on_save, :any, required: true
  
  # Internal state manages:
  # - available_fields (from behaviour)
  # - current_instance (being edited)
  # - selected_field (for configuration)
  # - preview_mode (toggle preview)
end
```

### Builder Interface

```
┌─────────────────────────────────────────────────────────┐
│ Form Builder                                    [Save]  │
├─────────────────┬───────────────────────────────────────┤
│ Field Palette   │ Form Canvas                           │
│                 │                                       │
│ □ Text Input    │ ┌─────────────────────────────────┐   │
│ □ Email         │ │ [Text Input] Name        [Edit] │   │
│ □ Number        │ └─────────────────────────────────┘   │
│ □ Checkbox      │                                       │
│ □ Dropdown      │ ┌─────────────────────────────────┐   │
│ □ Text Area     │ │ [Email] Email Address    [Edit] │   │
│                 │ └─────────────────────────────────┘   │
│                 │                                       │
│                 │ + Drop fields here                    │
├─────────────────┼───────────────────────────────────────┤
│ Field Config    │ Form Preview                          │
│                 │                                       │
│ Name: [____]    │ Name: [________________]              │
│ Label: [____]   │ Email: [________________]             │
│ Required: ☑     │                                       │
│ Validations:    │ [Submit]                              │
│ + Add Rule      │                                       │
└─────────────────┴───────────────────────────────────────┘
```

## Dynamic Form Renderer

The renderer provides two components for maximum flexibility:

1. **DynamicForm.Renderer** - A functional component for advanced use cases
2. **DynamicForm.RendererLive** - A LiveComponent wrapper for common scenarios

### DynamicForm.Renderer (Functional Component)

A pure functional component that renders the form HTML. Use this for advanced cases where you want custom state management:

```elixir
defmodule DynamicForm.Renderer do
  use Phoenix.Component
  import LftWeb.CoreComponents
  
  attr :instance, DynamicForm.Instance, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :submit_text, :string, default: nil
  attr :submit_event, :string, default: "submit"
  attr :validate_event, :string, default: "validate"
  attr :target, :any, default: nil
  attr :form_id, :string, default: "dynamic-form"
  attr :disabled, :boolean, default: false
  
  def render(assigns) do
    submit_text = assigns.submit_text || gettext("Submit")
    assigns = assign(assigns, :submit_text, submit_text)
    
    ~H"""
    <.simple_form 
      :let={f} 
      for={@form} 
      id={@form_id}
      phx-submit={@submit_event}
      phx-change={@validate_event}
      phx-target={@target}
    >
      <%= for field <- @instance.fields do %>
        <.render_field field={field} form={f} disabled={@disabled} />
      <% end %>
      
      <:actions>
        <.button disabled={@disabled} phx-disable-with={gettext("Saving...")}>
          <%= @submit_text %>
        </.button>
      </:actions>
    </.simple_form>
    """
  end
  
  defp render_field(%{type: :string} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.input 
      field={@form[String.to_atom(@field.name)]}
      type="text"
      label={@field.label}
      placeholder={@field.placeholder}
      help={@field.help_text}
      required={@field.required}
      disabled={@disabled}
    />
    """
  end
  
  defp render_field(%{type: :email} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.input 
      field={@form[String.to_atom(@field.name)]}
      type="email"
      label={@field.label}
      placeholder={@field.placeholder}
      help={@field.help_text}
      required={@field.required}
      disabled={@disabled}
    />
    """
  end
  
  defp render_field(%{type: :textarea} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.input 
      field={@form[String.to_atom(@field.name)]}
      type="textarea"
      label={@field.label}
      placeholder={@field.placeholder}
      help={@field.help_text}
      required={@field.required}
      disabled={@disabled}
    />
    """
  end
  
  defp render_field(%{type: :decimal} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.input 
      field={@form[String.to_atom(@field.name)]}
      type="number"
      step="0.01"
      label={@field.label}
      placeholder={@field.placeholder}
      help={@field.help_text}
      required={@field.required}
      disabled={@disabled}
    />
    """
  end
  
  defp render_field(%{type: :boolean} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.input 
      field={@form[String.to_atom(@field.name)]}
      type="checkbox"
      label={@field.label}
      help={@field.help_text}
      disabled={@disabled}
    />
    """
  end
  
  defp render_field(%{type: :select} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.input
      field={@form[String.to_atom(@field.name)]}
      type="select"
      label={@field.label}
      options={@field.options || []}
      help={@field.help_text}
      required={@field.required}
      disabled={@disabled}
    />
    """
  end

  # Render direct_upload field (file upload to cloud storage)
  defp render_field(%{type: :direct_upload} = field, form, opts \\ []) do
    disabled = Keyword.get(opts, :disabled, false)
    assigns = %{field: field, form: form, disabled: disabled}
    ~H"""
    <.live_component
      module={DynamicForm.DirectUpload}
      id={"#{@field.id}-upload-component"}
      field={@field}
      form={@form}
      disabled={@disabled}
    />
    """
  end

  # Fallback for unknown field types
  defp render_field(field, _form) do
    assigns = %{field: field}
    ~H"""
    <div class="text-red-500">
      <%= gettext("Unknown field type: %{type}", type: @field.type) %>
    </div>
    """
  end
end
```

### DynamicForm.RendererLive (LiveComponent)

A LiveComponent wrapper that handles form state management and backend submission automatically. Use this for most common scenarios:

```elixir
defmodule DynamicForm.RendererLive do
  use Phoenix.LiveComponent
  import LftWeb.CoreComponents
  alias DynamicForm.Renderer
  
  # Props
  attr :id, :string, required: true
  attr :instance, DynamicForm.Instance, required: true
  attr :params, :map, default: %{}
  attr :on_success_callback, :any, default: nil
  attr :on_error_callback, :any, default: nil
  attr :submit_text, :string, default: nil
  
  def mount(socket) do
    {:ok, socket}
  end
  
  def update(assigns, socket) do
    changeset = DynamicForm.Changeset.create_changeset(assigns.instance, assigns.params)
    form = to_form(changeset, as: "dynamic_form")
    
    {:ok, 
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:form, form)
     |> assign(:submitting, false)}
  end
  
  def render(assigns) do
    ~H"""
    <div>
      <Renderer.render
        instance={@instance}
        form={@form}
        submit_text={@submit_text}
        submit_event="submit"
        validate_event="validate"
        target={@myself}
        form_id={"#{@id}-form"}
        disabled={@submitting}
      />
    </div>
    """
  end
  
  def handle_event("validate", %{"dynamic_form" => params}, socket) do
    changeset = 
      socket.assigns.instance
      |> DynamicForm.Changeset.create_changeset(params)
      |> Map.put(:action, :validate)
    
    form = to_form(changeset, as: "dynamic_form")
    
    {:noreply, 
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, form)}
  end
  
  def handle_event("submit", %{"dynamic_form" => params}, socket) do
    changeset = DynamicForm.Changeset.create_changeset(socket.assigns.instance, params)
    
    case changeset.valid? do
      true ->
        # Set submitting state
        socket = assign(socket, :submitting, true)
        
        # Submit via backend
        instance = socket.assigns.instance
        backend_module = instance.backend.module
        backend_config = instance.backend.config
        
        case backend_module.submit(changeset, backend_config) do
          {:ok, result} ->
            # Call success callback if provided
            if socket.assigns.on_success_callback do
              socket.assigns.on_success_callback.(result)
            end
            
            {:noreply, assign(socket, :submitting, false)}
          
          {:error, error} ->
            # Call error callback if provided
            if socket.assigns.on_error_callback do
              socket.assigns.on_error_callback.(error)
            end
            
            {:noreply, assign(socket, :submitting, false)}
        end
      
      false ->
        changeset = Map.put(changeset, :action, :validate)
        form = to_form(changeset, as: "dynamic_form")
        {:noreply, 
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, form)}
    end
  end
end
```

## Changeset Utilities

Helper functions for creating dynamic changesets:

```elixir
defmodule DynamicForm.Changeset do
  
  @doc """
  Creates a changeset from a DynamicForm.Instance configuration
  """
  def create_changeset(instance, params \\ %{}) do
    types = build_types_map(instance.fields)
    required_fields = get_required_fields(instance.fields)
    
    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required(required_fields)
    |> apply_custom_validations(instance.fields)
  end
  
  defp build_types_map(fields) do
    Enum.reduce(fields, %{}, fn field, acc ->
      Map.put(acc, field.name, field.type)
    end)
  end
  
  defp get_required_fields(fields) do
    fields
    |> Enum.filter(& &1.required)
    |> Enum.map(& &1.name)
  end
  
  defp apply_custom_validations(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, acc ->
      apply_field_validations(acc, field)
    end)
  end
  
  defp apply_field_validations(changeset, field) do
    Enum.reduce(field.validations || [], changeset, fn validation, acc ->
      apply_validation(acc, field.name, validation)
    end)
  end
end
```

## Validation System

Support for custom validation types:

```elixir
defmodule DynamicForm.Validation do
  
  def apply_validation(changeset, field_name, %{type: :min_length, value: min}) do
    Ecto.Changeset.validate_length(changeset, field_name, min: min)
  end
  
  def apply_validation(changeset, field_name, %{type: :max_length, value: max}) do
    Ecto.Changeset.validate_length(changeset, field_name, max: max)
  end
  
  def apply_validation(changeset, field_name, %{type: :email_format}) do
    Ecto.Changeset.validate_format(changeset, field_name, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
  end
  
  def apply_validation(changeset, field_name, %{type: :numeric_range, min: min, max: max}) do
    changeset
    |> Ecto.Changeset.validate_number(field_name, greater_than_or_equal_to: min)
    |> Ecto.Changeset.validate_number(field_name, less_than_or_equal_to: max)
  end
  
  # Support for custom validators from behaviour
  def apply_validation(changeset, field_name, %{type: custom_type} = validation, custom_validators) do
    case Map.get(custom_validators, custom_type) do
      nil -> changeset
      validator_fn -> validator_fn.(changeset, field_name, validation)
    end
  end
end
```

## Database Schema

For persisting form configurations:

```elixir
defmodule DynamicForm.Schema do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  
  schema "dynamic_forms" do
    field :name, :string
    field :description, :string
    field :config, :map  # Stores the DynamicForm.Instance as JSON
    field :behaviour_module, :string
    field :active, :boolean, default: true
    
    # Add relationships as needed
    # belongs_to :user, User
    # belongs_to :organization, Organization
    
    timestamps()
  end
  
  def changeset(form, attrs) do
    form
    |> cast(attrs, [:name, :description, :config, :behaviour_module, :active])
    |> validate_required([:name, :config, :behaviour_module])
    |> validate_config_structure()
  end
  
  defp validate_config_structure(changeset) do
    # Validate that config contains valid DynamicForm.Instance structure
    changeset
  end
end
```

## Usage Examples

### 1. Implementing a Custom Form Behaviour

```elixir
defmodule MyApp.SurveyForm do
  @behaviour DynamicForm
  
  @impl DynamicForm
  def available_form_fields do
    [
      %{type: :string, label: gettext("Text Question"), icon: "text"},
      %{type: :textarea, label: gettext("Long Answer"), icon: "document-text"},
      %{type: :select, label: gettext("Multiple Choice"), icon: "list-bullet"},
      %{type: :boolean, label: gettext("Yes/No Question"), icon: "check-circle"},
      %{type: :decimal, label: gettext("Rating Scale"), icon: "star"}
    ]
  end
  
  @impl DynamicForm
  def select_options(:rating_scale), do: [{"1", 1}, {"2", 2}, {"3", 3}, {"4", 4}, {"5", 5}]
  def select_options(_), do: []
  
  @impl DynamicForm
  def validation_rules do
    [
      %{type: :required, label: gettext("Required Question")},
      %{type: :min_length, label: gettext("Minimum Characters"), has_value: true},
      %{type: :rating_range, label: gettext("Rating Range"), has_min_max: true}
    ]
  end
  
  @impl DynamicForm
  def custom_validators do
    %{
      rating_range: &validate_rating_range/3
    }
  end
  
  defp validate_rating_range(changeset, field_name, %{min: min, max: max}) do
    Ecto.Changeset.validate_number(changeset, field_name, 
      greater_than_or_equal_to: min, 
      less_than_or_equal_to: max
    )
  end
end
```

### 2. Using the WYSIWYG Builder in a LiveView

```elixir
defmodule MyAppWeb.SurveyBuilderLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form_instance: nil)}
  end
  
  def render(assigns) do
    ~H"""
    <.header>
      <%= gettext("Survey Builder") %>
    </.header>
    
    <.live_component
      module={DynamicForm.Builder}
      id="survey-builder"
      behaviour_module={MyApp.SurveyForm}
      instance={@form_instance}
      on_save={&handle_form_save/1}
    />
    """
  end
  
  defp handle_form_save(instance) do
    # Save the form instance to database
    # Redirect or show success message
  end
end
```

### 3. Simple Form Rendering (LiveComponent)

Most common use case - let the LiveComponent handle all form state and backend submission:

```elixir
defmodule MyAppWeb.SurveyResponseLive do
  use MyAppWeb, :live_view
  
  def mount(%{"id" => form_id}, _session, socket) do
    form_config = load_form_config(form_id)
    
    {:ok, assign(socket, 
      form_config: form_config,
      form_params: %{}
    )}
  end
  
  def render(assigns) do
    ~H"""
    <.header>
      <%= @form_config.name %>
      <:subtitle><%= @form_config.description %></:subtitle>
    </.header>
    
    <.live_component
      module={DynamicForm.RendererLive}
      id="survey-form"
      instance={@form_config}
      params={@form_params}
      on_success_callback={&optional_handle_form_success/1}
      on_error_callback={&optional_handle_form_error/1}
      submit_text={gettext("Submit Survey")}
    />
    """
  end
  
  defp optional_handle_form_success(result) do
    send(self(), {:form_success, result})
  end
  
  defp optional_handle_form_error(error) do
    send(self(), {:form_error, error})
  end
  
  def handle_info({:form_success, result}, socket) do
    {:noreply, 
     socket
     |> put_flash(:info, result.message || gettext("Survey submitted successfully!"))
     |> push_navigate(to: ~p"/surveys/thank-you")}
  end
  
  def handle_info({:form_error, error}, socket) do
    {:noreply, put_flash(socket, :error, error.message || gettext("Failed to submit survey"))}
  end
  
  defp load_form_config(form_id) do
    # Load from database or return example config
    %DynamicForm.Instance{
      id: form_id,
      name: gettext("Customer Satisfaction Survey"),
      description: gettext("Help us improve our service"),
      fields: [
        %DynamicForm.Instance.Field{
          id: "name",
          name: "name",
          type: :string,
          label: gettext("Your Name"),
          required: true,
          position: 1
        },
        %DynamicForm.Instance.Field{
          id: "email",
          name: "email", 
          type: :email,
          label: gettext("Email Address"),
          required: true,
          position: 2
        },
        %DynamicForm.Instance.Field{
          id: "rating",
          name: "rating",
          type: :select,
          label: gettext("Overall Rating"),
          options: [
            {gettext("Excellent"), "5"},
            {gettext("Good"), "4"},
            {gettext("Average"), "3"},
            {gettext("Poor"), "2"},
            {gettext("Very Poor"), "1"}
          ],
          required: true,
          position: 3
        }
      ],
      backend: %DynamicForm.Instance.Backend{
        module: MyApp.EmailBackend,
        function: :submit,
        config: [
          recipient_email: "surveys@myapp.com",
          subject: "New Customer Survey Response"
        ],
        name: "Email Submission",
        description: "Send survey responses via email"
      }
    }
  end
end
```

### 4. Advanced Form Rendering (Functional Component)

For complex scenarios where you need custom state management, conditional logic, or integration with existing forms:

```elixir
defmodule MyAppWeb.AdvancedSurveyLive do
  use MyAppWeb, :live_view
  
  def mount(%{"id" => form_id}, _session, socket) do
    form_config = load_form_config(form_id)
    changeset = DynamicForm.Changeset.create_changeset(form_config)
    form = to_form(changeset, as: "survey")
    
    {:ok, assign(socket, 
      form_config: form_config,
      changeset: changeset,
      form: form,
      step: 1,
      total_steps: 3,
      show_preview: false
    )}
  end
  
  def render(assigns) do
    ~H"""
    <.header>
      <%= @form_config.name %>
      <:subtitle>
        <%= gettext("Step %{step} of %{total}", step: @step, total: @total_steps) %>
      </:subtitle>
    </.header>
    
    <!-- Progress indicator -->
    <div class="mb-8">
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div 
          class="bg-blue-600 h-2 rounded-full transition-all duration-300" 
          style={"width: #{(@step / @total_steps) * 100}%"}
        >
        </div>
      </div>
    </div>
    
    <!-- Custom form wrapper with conditional rendering -->
    <div class="space-y-6">
      <%= if @show_preview do %>
        <div class="bg-gray-50 p-4 rounded-lg">
          <h3 class="font-medium mb-4"><%= gettext("Preview Your Responses") %></h3>
          <div class="space-y-2">
            <%= for {field, value} <- get_form_values(@changeset) do %>
              <div class="flex justify-between">
                <span class="font-medium"><%= field %>:</span>
                <span><%= value %></span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
      
      <!-- Use functional component with custom events -->
      <DynamicForm.Renderer.render
        instance={filter_fields_for_step(@form_config, @step)}
        form={@form}
        submit_text={get_submit_text(@step, @total_steps)}
        submit_event="handle_step"
        validate_event="validate_step"
        form_id="advanced-survey"
      />
      
      <!-- Custom navigation -->
      <div class="flex justify-between pt-4">
        <%= if @step > 1 do %>
          <.button type="button" phx-click="prev_step" variant="outline">
            <%= gettext("Previous") %>
          </.button>
        <% else %>
          <div></div>
        <% end %>
        
        <div class="space-x-2">
          <.button type="button" phx-click="toggle_preview" variant="outline">
            <%= if @show_preview, do: gettext("Hide Preview"), else: gettext("Show Preview") %>
          </.button>
          
          <%= if @step < @total_steps do %>
            <.button type="button" phx-click="save_draft" variant="outline">
              <%= gettext("Save Draft") %>
            </.button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
  
  def handle_event("validate_step", %{"survey" => params}, socket) do
    changeset = 
      socket.assigns.form_config
      |> DynamicForm.Changeset.create_changeset(params)
      |> Map.put(:action, :validate)
    
    form = to_form(changeset, as: "survey")
    
    {:noreply, 
     socket
     |> assign(:changeset, changeset)
     |> assign(:form, form)}
  end
  
  def handle_event("handle_step", %{"survey" => params}, socket) do
    changeset = DynamicForm.Changeset.create_changeset(socket.assigns.form_config, params)
    
    case changeset.valid? do
      true when socket.assigns.step < socket.assigns.total_steps ->
        # Move to next step
        form = to_form(changeset, as: "survey")
        {:noreply, 
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, form)
         |> assign(:step, socket.assigns.step + 1)}
      
      true ->
        # Final submission
        case save_survey_response(changeset) do
          {:ok, _response} ->
            {:noreply, 
             socket
             |> put_flash(:info, gettext("Survey completed successfully!"))
             |> push_navigate(to: ~p"/surveys/thank-you")}
          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, gettext("Failed to save survey"))}
        end
      
      false ->
        changeset = Map.put(changeset, :action, :validate)
        form = to_form(changeset, as: "survey")
        {:noreply, 
         socket
         |> assign(:changeset, changeset)
         |> assign(:form, form)}
    end
  end
  
  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, max(1, socket.assigns.step - 1))}
  end
  
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end
  
  def handle_event("save_draft", _params, socket) do
    # Save current progress as draft
    {:noreply, put_flash(socket, :info, gettext("Draft saved"))}
  end
  
  defp filter_fields_for_step(config, step) do
    # Custom logic to show different fields per step
    fields_per_step = Enum.chunk_every(config.fields, 2)
    step_fields = Enum.at(fields_per_step, step - 1, [])
    
    %{config | fields: step_fields}
  end
  
  defp get_submit_text(step, total_steps) do
    cond do
      step < total_steps -> gettext("Next Step")
      true -> gettext("Complete Survey")
    end
  end
  
  defp get_form_values(changeset) do
    changeset.changes
    |> Enum.map(fn {key, value} -> {humanize_field_name(key), value} end)
  end
  
  defp humanize_field_name(key) do
    key |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end
  
  # ... other helper functions
end
```

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Define DynamicForm behaviour
- [ ] Create DynamicForm.Instance struct
- [ ] Implement basic changeset utilities
- [ ] Create simple field renderer

### Phase 2: WYSIWYG Builder
- [ ] Build drag-and-drop interface
- [ ] Implement field configuration panel
- [ ] Add form preview functionality
- [ ] Create save/load functionality

### Phase 3: Advanced Features
- [ ] Custom validation system
- [ ] Field dependencies and conditional logic
- [ ] Form templates and presets
- [ ] Import/export functionality

### Phase 4: Integration & Polish
- [ ] Database persistence layer
- [ ] API for form management
- [ ] Comprehensive test suite
- [ ] Documentation and examples

## Technical Considerations

### Performance
- Use LiveView streams for large field lists
- Implement debounced autosave for builder
- Lazy load field configuration panels

### Accessibility
- Ensure WYSIWYG builder is keyboard navigable
- Generated forms must be screen reader friendly
- Proper ARIA labels and roles

### Security
- Validate all dynamic field configurations
- Sanitize user input in form fields
- Prevent XSS in dynamic form rendering

### Internationalization
- All UI text must use gettext
- Support for multi-language form labels
- RTL language support consideration

## Testing Strategy

### Unit Tests
- DynamicForm.Instance struct validation
- Changeset creation and validation
- Field rendering logic

### Integration Tests
- WYSIWYG builder interactions
- Form submission and validation
- Database persistence

### E2E Tests
- Complete form creation workflow
- Form response submission
- Multi-step form building

## Direct Upload Field Type

The `direct_upload` field type enables file uploads directly to cloud storage using presigned URLs, bypassing the application server for improved performance and scalability.

### Configuration

Direct upload fields require configuration via the `metadata` map:

```elixir
%DynamicForm.Instance.Field{
  id: "documents",
  name: "documents",
  type: "direct_upload",
  label: "Upload Documents",
  help_text: "Upload supporting documents (max 10MB per file)",
  required: true,
  metadata: %{
    "max_entries" => 3,
    "max_file_size" => 10_000_000,
    "accept" => [".pdf", ".doc", ".docx", "image/*"],
    "presigner" => %{
      "module" => "MyApp.UrlPresigner",
      "function" => "sign"
    },
    "bucket" => "my-uploads-bucket",
    "object_name_prefix" => "applications/documents/"
  }
}
```

### Metadata Options

- `max_entries` (integer): Maximum number of files that can be uploaded (default: 3)
- `max_file_size` (integer): Maximum file size in bytes (default: 10,000,000 = 10MB)
- `accept` (list or `:any`): Allowed file types (MIME types or extensions)
- `presigner` (map): Configuration for the presigner callback
  - `module` (string): Fully-qualified module name that implements the presigner
  - `function` (string): Function name to call for generating presigned URLs
- `bucket` (string): Cloud storage bucket name
- `object_name_prefix` (string): Prefix for object names in storage

### Presigner Implementation

The presigner module must implement a function with the signature:

```elixir
@spec sign(filename :: String.t(), context :: map()) :: String.t()
```

Example implementation:

```elixir
defmodule MyApp.UrlPresigner do
  def sign(filename, context) do
    bucket = context.bucket
    prefix = context.prefix || ""
    object_name = "#{prefix}#{filename}"

    # Use existing CoreData.Clients.UrlPresigner
    CoreData.Clients.UrlPresigner.sign(bucket, object_name)
  end
end
```

### Uploaded Files Data Structure

Uploaded files are stored in the changeset as a list of maps:

```elixir
[
  %{
    "filename" => "document.pdf",
    "cloud_bucket" => "my-uploads-bucket",
    "cloud_path" => "applications/documents/document.pdf",
    "cloud_provider" => "gcp",
    "uploaded_on" => "10/28/2025"
  }
]
```

### LiveView Integration

The DirectUpload component sends messages to the parent LiveView:

- `:uploads_not_ready` - When upload starts or all files are deleted
- `:uploads_ready` - When all uploads complete

Handle these messages in your LiveView:

```elixir
def handle_info(:uploads_not_ready, socket) do
  # Optionally disable submit or show loading state
  {:noreply, socket}
end

def handle_info(:uploads_ready, socket) do
  # Re-enable submit button
  {:noreply, socket}
end
```

### Complete Example

See `example/direct_upload_example.ex` for a comprehensive example including:
- Form configuration with direct_upload fields
- Presigner implementation
- Backend processing of uploaded files
- LiveView integration
- Migration from DirectorWeb upload pattern

## Future Enhancements

- **Conditional Logic**: Show/hide fields based on other field values ✅ (Implemented)
- **Multi-page Forms**: Support for wizard-style forms
- **File Uploads**: Dynamic file upload fields ✅ (Implemented as `direct_upload`)
- **Rich Text**: WYSIWYG text editor fields
- **Form Analytics**: Track form performance and completion rates
- **A/B Testing**: Support for form variations
- **Integration APIs**: Connect with external services (CRM, email, etc.)

---

This document serves as the foundation for implementing the DynamicForm library. Each section can be expanded with more detailed specifications as development progresses.
