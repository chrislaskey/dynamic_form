defmodule DynamicForm.Components.ContentElements do
  @moduledoc """
  Rendering for non-question elements: `html` and `image` content blocks,
  fully custom slot elements, and `panel` containers (whose members render
  back through `DynamicForm.Renderer.Component`).

  Internal module — not part of the public API.
  """

  use Phoenix.Component

  alias DynamicForm.Components
  alias DynamicForm.Helpers
  alias DynamicForm.Instance
  alias DynamicForm.Renderer.Component
  alias DynamicForm.Visibility

  # A group with no groupType of its own lays its members out in a row
  @default_group_type "horizontal"

  # Render HTML elements defined with a slot body (see Instance.FromSlots).
  # The body is compile-checked HEEx, so unlike the html-string clause below it
  # is escaped by default and can read the defining template's assigns.
  def render(%Instance.Element{type: "html", slot: entry}, _form, _opts)
      when not is_nil(entry) do
    assigns = %{entry: entry}

    ~H"""
    <div class="mb-4">
      {render_slot(@entry)}
    </div>
    """
  end

  # Render fully custom elements: the slot body receives the Phoenix form so
  # it can read current values, e.g. <:field type="custom" :let={form}>
  def render(%Instance.Element{type: "custom", slot: entry}, form, opts)
      when not is_nil(entry) do
    assigns = %{entry: entry, form: Helpers.Form.put_data(form, Keyword.get(opts, :form_data))}

    ~H"""
    <div class="mb-4">
      {render_slot(@entry, @form)}
    </div>
    """
  end

  # Render HTML elements
  def render(%Instance.Element{type: "html"} = element, _form, _opts) do
    html_content = element.html || ""

    assigns = %{html: html_content}

    ~H"""
    <div class="mb-4">
      <%= Phoenix.HTML.raw(@html) %>
    </div>
    """
  end

  # Render image elements
  def render(%Instance.Element{type: "image"} = element, _form, _opts) do
    assigns = %{element: element}

    ~H"""
    <div class="mb-4">
      <img
        src={@element.imageLink}
        alt={@element.title || @element.name}
        style={image_style(@element)}
        class="rounded-md max-w-full"
      />
    </div>
    """
  end

  # Render panel elements (containers)
  def render(%Instance.Element{type: "panel"} = element, form, opts) do
    elements = element.elements || []

    # A disabled panel (enableIf false) disables every question inside it
    opts =
      if Visibility.condition_met?(element.enableIf, Helpers.Form.get_params(form)) do
        opts
      else
        Keyword.put(opts, :disabled, true)
      end

    # Filter visible elements within the panel
    visible_panel_elements = Visibility.visible_elements(elements, Helpers.Form.get_params(form))

    assigns = %{
      element: element,
      # nil rather than "" for a blank title: the group component renders no
      # heading when it has none
      title: if(Instance.blank?(element.title), do: nil, else: element.title),
      group_type: element.groupType || @default_group_type,
      # The effective state: a group inherits it from a disabled form or an
      # enclosing disabled group as well as from its own enableIf
      disabled: Keyword.get(opts, :disabled, false),
      elements: visible_panel_elements,
      form: form,
      opts: opts,
      components: Keyword.get(opts, :components)
    }

    ~H"""
    {Components.render(@components, :dynamic_form_group, %{
      type: @group_type,
      name: @element.name,
      title: @title,
      disabled: @disabled,
      inner_block: [
        %{
          __slot__: :inner_block,
          inner_block: fn _changed, _arg -> render_panel_elements(@elements, @form, @opts) end
        }
      ]
    })}
    """
  end

  # Unknown element types render nothing — obvious in testing, not
  # broken-looking in production
  def render(_element, _form, _opts) do
    assigns = %{}

    ~H""
  end

  # The contents of a panel, wrapped in a slot for the group component
  defp render_panel_elements(elements, form, opts) do
    assigns = %{elements: elements, form: form, opts: opts}

    ~H"""
    <%= for element <- @elements do %>
      <%= Component.render_element(element, @form, @opts) %>
    <% end %>
    """
  end

  defp image_style(element) do
    [
      element.imageWidth && "width: #{element.imageWidth};",
      element.imageHeight && "height: #{element.imageHeight};",
      element.imageFit && "object-fit: #{element.imageFit};"
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end
end
