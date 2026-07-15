defmodule ExampleWeb.PageController do
  use ExampleWeb, :controller

  def home(conn, _params) do
    # Create a simple test instance using SurveyJS format
    test_instance = %DynamicForm.Instance{
      id: "test-1",
      title: "Test Form",
      description: "A test form to verify library loading",
      elements: [],
      backend: %DynamicForm.Instance.Backend{
        module: Example.TestBackend,
        function: :submit,
        config: []
      }
    }

    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home,
      layout: false,
      test_instance: test_instance
    )
  end
end
