defmodule Dufa.APNS do
  @moduledoc """
  APNS pusher.
  """

  @behaviour Dufa.Pusher

  @doc """
  Pushes a `push_message` via APNS with provided `opts` options.
  Invokes a `on_response_callback` on a response.
  """
  @spec push(Dufa.APNS.PushMessage.t, map(), fun() | nil) :: {:noreply, map()}
  def push(push_message, opts \\ %{}, on_response_callback \\ nil)

  def push(push_message, %{mode: _mode} = opts, on_response_callback) do
    stop_and_push(push_message, opts, on_response_callback)
  end

  def push(push_message, %{cert: _cert} = opts, on_response_callback) do
    stop_and_push(push_message, opts, on_response_callback)
  end

  def push(push_message, %{key: _key} = opts, on_response_callback) do
    stop_and_push(push_message, opts, on_response_callback)
  end

  def push(push_message, opts, on_response_callback) do
    do_push(push_message, opts, on_response_callback)
  end

  @spec push(Dufa.APNS.PushMessage.t, map(), fun()) :: {:noreply, map()}
  defp stop_and_push(push_message, opts, on_response_callback) do
    with {:ok, client} <- Dufa.APNS.Registry.lookup(:apns_registry, push_message.token) do
      unless opts_equal?(opts, Dufa.APNS.Client.current_ssl_config(client)) do
        Dufa.APNS.Client.stop(client)
      end
    end
    do_push(push_message, opts, on_response_callback)
  end

  defp opts_equal?(opts, config) do
    opts[:mode] == config.mode &&
    opts[:cert] == config.cert &&
    opts[:key]  == config.key
  end

  @spec push(Dufa.APNS.PushMessage.t, map(), fun()) :: {:noreply, map()}
  defp do_push(push_message, opts, on_response_callback) do
    :apns_registry
    |> Dufa.APNS.Registry.create(push_message.token, opts)
    |> Dufa.APNS.Client.push(push_message, opts, on_response_callback)
  end
end
