defmodule Demo.SampleContact do
  @moduledoc false
  defstruct [
    :name,
    :email,
    :phone,
    :preferred_contact,
    :subject,
    :message,
    :priority,
    :subscribe,
    :newsletter_frequency
  ]
end
