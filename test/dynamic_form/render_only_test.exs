defmodule DynamicForm.RenderOnlyTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias DynamicForm.Instance

  @instance %Instance{
    id: "signup",
    elements: [
      %Instance.Question{name: "name", type: "text", title: "Name", isRequired: true},
      %Instance.Question{name: "email", type: "text", inputType: "email", title: "Email"}
    ]
  }

  defp parent_form(params \\ %{}, opts \\ []) do
    types = %{name: :string, email: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:name])
    |> Map.put(:action, Keyword.get(opts, :action))
    |> Phoenix.Component.to_form(as: Keyword.get(opts, :as, "signup"))
  end

  defp render_only(overrides \\ []) do
    assigns =
      Keyword.merge(
        [id: "signup", render_only: true, instance: @instance, form: parent_form()],
        overrides
      )

    render_component(&DynamicForm.form/1, assigns)
  end

  describe "render-only mode" do
    test "renders the definition against the parent-owned form" do
      html = render_only()

      assert html =~ ~s(id="signup-form")
      assert html =~ ~s(name="signup[name]")
      assert html =~ ~s(name="signup[email]")
    end

    test "emits parent-targeted events with default names" do
      html = render_only()

      assert html =~ ~s(phx-change="validate")
      assert html =~ ~s(phx-submit="submit")
      refute html =~ "phx-target"
    end

    test "phx_change and phx_submit override the event names" do
      html = render_only(phx_change: "check", phx_submit: "save")

      assert html =~ ~s(phx-change="check")
      assert html =~ ~s(phx-submit="save")
    end

    test "renders errors from the parent's changeset" do
      # Browser-shaped params: every input submits, untouched ones as ""
      form = parent_form(%{"name" => "", "email" => "x"}, action: :validate)

      html = render_only(form: form)

      assert html =~ "can&#39;t be blank"
    end

    test "works with slot-defined fields" do
      field = %{__slot__: :field, inner_block: nil, type: "text", name: "name", label: "Name"}

      html =
        render_component(&DynamicForm.form/1,
          id: "signup",
          render_only: true,
          form: parent_form(),
          field: [field]
        )

      assert html =~ ~s(name="signup[name]")
      refute html =~ "phx-target"
    end
  end

  describe "render-only attribute validation" do
    test "raises without a form" do
      assert_raise ArgumentError, ~r/render_only requires the form attribute/, fn ->
        render_component(&DynamicForm.form/1,
          id: "signup",
          render_only: true,
          instance: @instance
        )
      end
    end

    test "raises when lifecycle attributes are given" do
      for attrs <- [
            [on_change: fn payload -> payload end],
            [change_debounce_in_ms: 300],
            [on_submit: fn payload -> payload end],
            [on_success: fn _payload -> :ok end],
            [send_message_on: [:change]],
            [data: %{"name" => "Chris"}],
            [form_name: "custom"],
            [validation_summary: "detailed"]
          ] do
        assert_raise ArgumentError, ~r/render_only renders markup only/, fn ->
          render_only(attrs)
        end
      end
    end

    test "raises on file upload questions" do
      instance = %Instance{
        id: "docs",
        elements: [%Instance.Question{name: "documents", type: "file", title: "Documents"}]
      }

      assert_raise ArgumentError, ~r/does not support file upload questions \(documents\)/, fn ->
        render_only(instance: instance)
      end
    end
  end

  describe "stateful-mode attribute validation" do
    test "raises when render-only attributes are given without render_only" do
      for attrs <- [
            [form: parent_form()],
            [phx_change: "check"],
            [phx_submit: "save"]
          ] do
        assert_raise ArgumentError, ~r/without render_only/, fn ->
          render_component(
            &DynamicForm.form/1,
            Keyword.merge([id: "signup", instance: @instance], attrs)
          )
        end
      end
    end
  end
end
