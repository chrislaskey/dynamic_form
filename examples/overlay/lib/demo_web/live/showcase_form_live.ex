defmodule DemoWeb.ShowcaseFormLive do
  @moduledoc """
  Every supported question type on one form, defined as SurveyJS-compatible
  JSON: text inputs, comment, dropdown, radiogroup, checkbox, boolean,
  rating, tagbox, html content blocks, panels, conditional visibility, and
  a direct-to-cloud file upload backed by the demo's mock presigner.
  """

  use DemoWeb, :live_view

  import DemoWeb.DemoComponents

  @impl true
  def mount(_params, _session, socket) do
    json = File.read!(Path.join(:code.priv_dir(:demo), "surveyjs_test_form.json"))

    {:ok,
     assign(socket,
       json: json,
       instance: DynamicForm.Instance.decode!(json),
       submitted_data: nil
     )}
  end

  # Only valid submissions arrive here — invalid ones render their errors
  # inline on the form. This is where the side effect happens.
  @impl true
  def handle_info({:dynamic_form, %DynamicForm.Payload{data: data}}, socket) do
    {:ok, _result} = Demo.Submissions.create(data)

    {:noreply,
     socket
     |> assign(:submitted_data, data)
     |> put_flash(:info, "Showcase form submitted successfully")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-5xl">
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Question Type Showcase</h1>
          <p class="mt-2 text-gray-600">
            Every supported question type on one form — text, comment,
            dropdown, radiogroup, checkbox, boolean, rating, tagbox, html
            content blocks, panels, and a direct-to-cloud file upload using the
            demo's mock presigner (<code class="bg-gray-100 px-1 rounded">Demo.MockUrlPresigner</code>).
            The definition is SurveyJS-compatible JSON decoded at mount;
            <code class="bg-gray-100 px-1 rounded">validation_summary="detailed"</code>
            lists every error above the form on an invalid submit.
          </p>
        </div>

        <.definition
          title="Form Definition (JSON)"
          subtitle="priv/surveyjs_test_form.json, decoded with DynamicForm.Instance.decode!/1"
          code={@json}
        />

        <div class="rounded-lg bg-white shadow-sm ring-1 ring-gray-900/5 p-6">
          <DynamicForm.form id="showcase-form" instance={@instance} validation_summary="detailed" />
        </div>

        <div :if={@submitted_data} class="mt-8 rounded-lg bg-green-50 p-6">
          <h3 class="text-lg font-semibold text-green-900 mb-4">Submitted Data</h3>
          <pre class="bg-green-100 p-4 rounded overflow-x-auto text-sm text-green-800"><%= inspect(@submitted_data, pretty: true) %></pre>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
