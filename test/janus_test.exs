defmodule JanusTest do
  use ExUnit.Case, async: true
  doctest Janus

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass}
  end

  describe "Janus.info/1" do

    test "returns information on the Janus server", %{bypass: bypass}  do
      {:ok, response} = Poison.encode(%{})
      Bypass.expect bypass, fn(conn) ->
        assert conn.request_path == "/janus/info"
        assert conn.method == "GET"
        Plug.Conn.resp(conn, 200, response)
      end
      {:ok, info} = Janus.info("http://localhost:#{bypass.port}/janus")
      assert is_map(info)
    end

  end

end
