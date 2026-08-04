defmodule DynamicForm.PayloadTest do
  use ExUnit.Case, async: true

  alias DynamicForm.Payload

  defp changeset(params \\ %{"name" => "Ada"}) do
    types = %{name: :string, email: :string}

    {%{}, types}
    |> Ecto.Changeset.cast(params, Map.keys(types))
    |> Ecto.Changeset.validate_required([:name])
  end

  describe "new/2" do
    test "builds a payload from the component id and changeset" do
      payload = Payload.new("contact-form", changeset())

      assert %Payload{
               id: "contact-form",
               data: %{name: "Ada"},
               extra: %{}
             } = payload

      assert payload.changeset.valid?
    end
  end

  describe "add_error/4" do
    test "adds a changeset error, marking the submission invalid" do
      payload =
        "contact-form"
        |> Payload.new(changeset())
        |> Payload.add_error(:email, "has already been taken")

      refute payload.changeset.valid?
      assert {"has already been taken", []} = payload.changeset.errors[:email]
    end

    test "passes opts through to the changeset error" do
      payload =
        "contact-form"
        |> Payload.new(changeset())
        |> Payload.add_error(:name, "too short", count: 2)

      assert {"too short", [count: 2]} = payload.changeset.errors[:name]
    end
  end

  describe "put_extra/3" do
    test "stores derived data on the payload" do
      payload =
        "contact-form"
        |> Payload.new(changeset())
        |> Payload.put_extra(:normalized_phone, "+15555550100")

      assert payload.extra == %{normalized_phone: "+15555550100"}
    end
  end

  describe "valid?/1" do
    test "reads the changeset's valid? flag" do
      assert Payload.valid?(Payload.new("f", changeset()))
      refute Payload.valid?(Payload.new("f", changeset(%{})))
    end

    test "false after add_error" do
      payload =
        "f"
        |> Payload.new(changeset())
        |> Payload.add_error(:name, "nope")

      refute Payload.valid?(payload)
    end
  end
end
