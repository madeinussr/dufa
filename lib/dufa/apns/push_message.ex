defmodule Dufa.APNS.PushMessage do
  @derive [Poison.Encoder]

  @enforce_keys [:token]

  @type t :: %__MODULE__{token: String.t, topic: String.t, aps: Dufa.APNS.Aps.t, custom_data: map()}

  defstruct token: nil,
            topic: nil,
            aps: nil,
            custom_data: %{}
end
