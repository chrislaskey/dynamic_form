defmodule DemoWeb.IndexLive do
  @moduledoc """
  Home page listing every DynamicForm demo in the app.
  """

  use DemoWeb, :live_view

  @pages [
    {"/slot-forms", "Slot-Based Form Definitions",
     "Declarative <DynamicForm.form> definitions: <:field> slots, <:group> panels, custom markup via slot bodies, and an input-preservation test across parent re-renders"},
    {"/form-test-component", "LiveComponent Renderer",
     "DynamicForm.RendererLive usage modes (message passing vs self-contained) and external submit buttons"},
    {"/form-test", "Functional Renderer",
     "DynamicForm.Renderer with manual state management in the parent LiveView"},
    {"/render", "Create vs Edit Mode",
     "The same form instance rendered empty and pre-populated with params"},
    {"/showcase-form", "Question Type Showcase",
     "Every supported question type on one form, including file uploads via a mock presigner"},
    {"/payment-form", "Payment Form",
     "Conditional visibility driven by a payment method dropdown"},
    {"/section-form", "Sections (Panels)",
     "Panel elements grouping questions, with conditional section visibility"},
    {"/nested-forms", "Nested Forms (paneldynamic)",
     "Repeating child forms the user adds/removes — defined as SurveyJS JSON and as <:nested> slots, validated per entry"},
    {"/surveyjs-test", "SurveyJS JSON Decoding",
     "Instances decoded from SurveyJS-compatible JSON files at runtime"},
    {"/builder-mockups", "WYSIWYG Builder Mockups",
     "Static mockups of the form builder interface"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :pages, @pages)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <h1 class="text-3xl font-bold text-gray-900">DynamicForm Demos</h1>
        <p class="mt-2 text-gray-600">
          A full Phoenix application exercising the
          <a
            href="https://github.com/chrislaskey/dynamic_form"
            class="font-semibold text-indigo-600 hover:text-indigo-500"
          >
            DynamicForm
          </a>
          library — declarative slot definitions, SurveyJS-compatible data
          definitions, validation, conditional logic, and backend submission.
        </p>

        <ul class="mt-8 divide-y divide-zinc-100">
          <li :for={{path, title, description} <- @pages} class="py-4">
            <.link navigate={path} class="group block">
              <span class="font-semibold text-indigo-600 group-hover:text-indigo-500">
                {title} →
              </span>
              <p class="mt-1 text-sm text-gray-600">{description}</p>
              <code class="text-xs text-gray-400">{path}</code>
            </.link>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
