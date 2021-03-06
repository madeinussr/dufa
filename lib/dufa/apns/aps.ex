defmodule Dufa.APNS.Aps do
  @derive [Poison.Encoder]

  @type t :: %__MODULE__{content_available: pos_integer(),
                         badge: pos_integer(),
                         sound: String.t,
                         category: String.t,
                         alert: Dufa.APNS.Alert.t}

  defstruct content_available: nil,
            badge: nil,
            sound: nil,
            category: nil,
            alert: nil
end
