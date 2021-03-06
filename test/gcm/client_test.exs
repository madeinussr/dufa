defmodule GCM.ClientTest do
  use ExUnit.Case, async: false

  import Mock

  alias Dufa.GCM.Client
  alias Dufa.GCM.PushMessage
  alias Dufa.GCM.Notification

  @uri_path "https://gcm-http.googleapis.com/gcm/send"

  @successful_response %HTTPoison.Response{
    status_code: 200,
    body: ~S({"results":["everything is fine"]})
  }
  @errors_response %HTTPoison.Response{
    status_code: 200,
    body: ~S({"results":[{"error":"oops"}, {"error":"oops2"}]})
  }

  setup do
    registration_id = "your_registration_id"
    notification = %Notification{title: "Title", body: "Body"}
    push_message = %PushMessage{
      registration_ids: [registration_id],
      notification: notification,
      data: %{}
    }

    {:ok, push_message: push_message}
  end

  test "push/4: stops current process", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> @successful_response end]) do
      {:ok, client} = Dufa.GCM.Supervisor.start_client
      Client.push(client, push_message, %{}, nil)

      ref = Process.monitor(client)
      assert_receive {:DOWN, ^ref, _, _, _}
      refute Process.alive?(client)
    end
  end

  test "api_key_for/1: returns the value if opts has :api_key key" do
    assert Client.api_key_for(%{api_key: "qwerty"}) == "qwerty"
  end

  test "api_key_for/1: returns the value from the config if opts has not :api_key key" do
    assert Client.api_key_for(%{not_api_key: "qwerty"}) == Application.get_env(:dufa, :gcm_api_key)
  end

  test "do_push/3: makes a proper POST to GCM servise", %{push_message: push_message} do
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "key=qwerty"}
    ]

    payload = Poison.encode!(push_message)

    with_mock(HTTPoison, [post: fn (_, _, _) -> @successful_response end]) do
      Client.do_push(push_message, "qwerty", nil)
      assert called HTTPoison.post(@uri_path, payload, headers)
    end
  end

  test "do_push/3: returns {:error, :unauthorized} if response status is 401", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, %HTTPoison.Response{status_code: 401}} end]) do
      assert Client.do_push(push_message, "", nil) == {:error, :unauthorized}
    end
  end

  test "do_push/3: returns {:error, %{status: pos_integer(), body: any()}} if response status is neither 200 nor 401", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, %HTTPoison.Response{status_code: 500, body: "omg"}} end]) do
      assert Client.do_push(push_message, "", nil) == {:error, %{status: 500, body: "omg"}}
    end
  end

  test "do_push/3: returns {:error, %{status: pos_integer(), body: any()}} if response status is 200 and body has any error", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, @errors_response} end]) do
      assert Client.do_push(push_message, "", nil) == {:error, %{status: @errors_response.status_code, body: @errors_response.body}}
    end
  end

  test "do_push/3: returns {:ok, %{status: pos_integer(), body: any()}} if response status is 200 and body has not errors", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, @successful_response} end]) do
      assert Client.do_push(push_message, "", nil) == {:ok, %{status: @successful_response.status_code, body: @successful_response.body}}
    end
  end

  test "do_push/3: invokes a callback on successful response", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, @successful_response} end]) do
      defmodule Callbacker do
        def callback(_push_message, response), do: response
      end

      with_mock(Callbacker, [callback: fn (_, response) -> response end]) do
        callback = fn (push_message, response) -> Callbacker.callback(push_message, response) end
        assert Client.do_push(push_message, "", callback)
        assert called Callbacker.callback(push_message, {:ok, %{status: @successful_response.status_code, body: @successful_response.body}})
      end
    end
  end

  test "do_push/3: invokes a callback on error response", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, @errors_response} end]) do
      defmodule Callbacker do
        def callback(_push_message, response), do: response
      end

      with_mock(Callbacker, [callback: fn (_, response) -> response end]) do
        callback = fn (push_message, response) -> Callbacker.callback(push_message, response) end
        assert Client.do_push(push_message, "", callback)
        assert called Callbacker.callback(push_message, {:error, %{status: @errors_response.status_code, body: @errors_response.body}})
      end
    end
  end

  test "do_push/3: invokes a callback on unauthorized request", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, %HTTPoison.Response{status_code: 401}} end]) do
      defmodule Callbacker do
        def callback(_push_message, response), do: response
      end

      with_mock(Callbacker, [callback: fn (_, response) -> response end]) do
        callback = fn (push_message, response) -> Callbacker.callback(push_message, response) end
        assert Client.do_push(push_message, "", callback)
        assert called Callbacker.callback(push_message, {:error, %{status: 401, body: nil}})
      end
    end
  end

  test "do_push/3: invokes a callback on request with unhandled error", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, %HTTPoison.Response{status_code: 500}} end]) do
      defmodule Callbacker do
        def callback(_push_message, response), do: response
      end

      with_mock(Callbacker, [callback: fn (_, response) -> response end]) do
        callback = fn (push_message, response) -> Callbacker.callback(push_message, response) end
        assert Client.do_push(push_message, "", callback)
        assert called Callbacker.callback(push_message, {:error, %{status: 500, body: nil}})
      end
    end
  end

  test "push/3: if opts[:delay] == true send push with defined delay", %{push_message: push_message} do
    with_mock(HTTPoison, [post: fn (_, _, _) -> {:ok, @successful_response} end]) do
      opts = %{delay: 1}
      t1 = :erlang.timestamp

      callback = fn (_push_message, _response) ->
        t2 = :erlang.timestamp
        assert :timer.now_diff(t2, t1) >= opts[:delay] * 1_000_000
      end

      {:ok, client} = Dufa.GCM.Supervisor.start_client
      ref = Process.monitor(client)

      Client.push(client, push_message, opts, callback)

      assert_receive {:DOWN, ^ref, _, _, _}, opts[:delay] * 1000 + 100
      refute Process.alive?(client)
    end
  end
end
