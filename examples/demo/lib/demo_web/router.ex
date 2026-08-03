defmodule DemoWeb.Router do
  use DemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DemoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", DemoWeb do
    pipe_through :browser

    live "/", IndexLive
    live "/slot-forms", SlotFormLive
    live "/form-test", FormTestLive
    live "/form-test-component", FormTestComponentLive
    live "/render", RenderLive
    live "/payment-form", PaymentFormLive
    live "/showcase-form", ShowcaseFormLive
    live "/section-form", SectionFormLive
    live "/surveyjs-test", SurveyjsTestLive
    live "/builder-mockups", BuilderMockupsLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", DemoWeb do
  #   pipe_through :api
  # end
end
