defmodule DynamicForm.Payload do
  @moduledoc """
  The value threaded through the form lifecycle.

  The component builds a payload from the form's changeset on every change and
  submit. Lifecycle callbacks (`on_change` and `on_submit`) receive the payload
  and return it — transformed or untouched — and a valid submission is
  delivered to the parent LiveView as `{:dynamic_form, payload}` when
  `send_messages` is set.

  ## Fields

    * `:id` - The form component's id, for matching in `handle_info/2`
    * `:changeset` - The form's `Ecto.Changeset` after built-in validations
      and any callbacks so far. Its `valid?` flag is the single source of
      truth for whether the submission is valid.
    * `:data` - The applied changeset data (`Ecto.Changeset.apply_changes/1`)
    * `:extra` - Empty map by default; callbacks can stash derived data here
      (a normalized phone number, a geocoded address) for the parent's
      `handle_info/2` to use

  ## Marking a payload invalid

  Validity lives on the changeset — there is no separate flag to keep in
  sync. Reject a submission with `add_error/4`: the error renders inline on
  the form field, the changeset becomes invalid, and the submission is
  withheld from the parent:

      def on_submit(payload) do
        if phone_number_valid?(payload.data[:phone]) do
          payload
        else
          DynamicForm.Payload.add_error(payload, :phone, "is not a valid phone number")
        end
      end
  """

  alias Ecto.Changeset

  @enforce_keys [:id, :changeset, :data]
  defstruct [:id, :changeset, :data, extra: %{}]

  @type t :: %__MODULE__{
          id: String.t(),
          changeset: Changeset.t(),
          data: map(),
          extra: map()
        }

  @doc """
  Builds a payload from a form component id and its changeset.

  `data` is the applied changeset data.
  """
  @spec new(String.t(), Changeset.t()) :: t()
  def new(id, %Changeset{} = changeset) do
    %__MODULE__{
      id: id,
      changeset: changeset,
      data: Changeset.apply_changes(changeset),
      extra: %{}
    }
  end

  @doc """
  Adds an error to the payload's changeset, marking the submission invalid.

  The way for `on_change`/`on_submit` callbacks to reject a submission: the
  error renders inline on the form field, and the changeset's `valid?` flag
  flips to `false` (as with any `Ecto.Changeset.add_error/4` call).

  Accepts the same arguments as `Ecto.Changeset.add_error/4`.
  """
  @spec add_error(t(), atom(), String.t(), keyword()) :: t()
  def add_error(%__MODULE__{} = payload, field, message, opts \\ []) do
    %{payload | changeset: Changeset.add_error(payload.changeset, field, message, opts)}
  end

  @doc """
  Stores a value under `key` in the payload's `extra` map.

  Lets `on_submit` pass derived data forward to the parent's `handle_info/2`
  without a side effect:

      payload
      |> DynamicForm.Payload.put_extra(:normalized_phone, normalized)
  """
  @spec put_extra(t(), term(), term()) :: t()
  def put_extra(%__MODULE__{} = payload, key, value) do
    %{payload | extra: Map.put(payload.extra, key, value)}
  end

  @doc """
  Whether the payload represents a valid submission.

  Reads the changeset's `valid?` flag — the single source of truth.
  """
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = payload) do
    payload.changeset.valid?
  end
end
