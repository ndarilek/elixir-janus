import Janus.Util

defmodule Janus.Plugin do
  @moduledoc """
  Send messages, trickle candidates, and detach plugins from Janus sessions.
  """

  @enforce_keys [:id, :base_url, :event_manager]
  defstruct [
    :id,
    :base_url,
    :event_manager,
    :cookie,
    :room_number
  ]

  @doc """
  Send `body` as a message to the specified plugin, along with an optional JSEP payload.
  """

  def message(pid, body, jsep \\ nil) do
    plugin = Agent.get(pid, & &1)

    IO.inspect("~~~ see body ": body)

    body =
      if body.request == "join" or body.request == "start" or body.request == "exists" do
        IO.inspect("~~~ in if ": body.request)
        maybe_add_key(body, :room, plugin.room_number)
      else
        IO.inspect("~~~ in else ": body.request)
        body
      end

    msg = %{body: body, janus: "message"}

    post(plugin.base_url, plugin.cookie, maybe_add_key(msg, :jsep, jsep))
  end

  def check_room_exists(plugin_base_url, body, cookie) do
    msg = %{body: body, janus: "message"}

    post(plugin_base_url, cookie, msg)
  end

  def create(plugin_base_url, body, cookie) do
    msg = %{body: body, janus: "message"}
    post(plugin_base_url, cookie, msg)
  end

  @doc """
  Hang up any Web RTC connections associated with this plugin.
  """

  def hangup(pid) do
    plugin = Agent.get(pid, & &1)

    case post(plugin.base_url, plugin.cookie, %{janus: :hangup}) do
      {:ok, _} -> :ok
      v -> v
    end
  end

  @doc """
  Trickle ICE candidates to this plugin.

  `candidates` is one or more of the following:
  * A single ICE candidate as a map.
  * A list of ICE candidate maps.
  * `nil`, meaning trickling is completed.
  """

  def trickle(pid, candidates \\ nil) do
    msg = %{janus: :trickle}

    msg =
      case candidates do
        nil -> Map.put(msg, :candidate, %{completed: true})
        v when is_list(v) -> Map.put(msg, :candidates, v)
        v when is_map(v) -> Map.put(msg, :candidate, v)
      end

    plugin = Agent.get(pid, & &1)
    post(plugin.base_url, plugin.cookie, msg)
  end

  @doc """
  Detaches this plugin from its session.

  Once this plugin is detached, it is invalid and can no longer be used.
  """

  def detach(pid) do
    base_url = Agent.get(pid, & &1.base_url)
    cookie = Agent.get(pid, & &1.cookie)
    post(base_url, cookie, %{janus: :detach})
    Agent.stop(pid)
  end

  @doc "See `GenEvent.add_handler/3`."
  def add_handler(plugin, handler, args),
    do: Agent.get(plugin, &GenEvent.add_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.add_mon_handler/3`."
  def add_mon_handler(plugin, handler, args),
    do: Agent.get(plugin, &GenEvent.add_mon_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.call/4`."
  def call(plugin, handler, timeout, request \\ 5000),
    do: Agent.get(plugin, &GenEvent.call(&1.event_manager, handler, request, timeout))

  @doc "See `GenEvent.remove_handler/3`."
  def remove_handler(plugin, handler, args),
    do: Agent.get(plugin, &GenEvent.remove_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.stream/2`."
  def stream(plugin, options \\ []),
    do: Agent.get(plugin, &GenEvent.stream(&1.event_manager, options))

  @doc "See `GenEvent.swap_handler/5`."
  def swap_handler(plugin, handler1, args1, handler2, args2),
    do:
      Agent.get(
        plugin,
        &GenEvent.swap_handler(&1.event_manager, handler1, args1, handler2, args2)
      )

  @doc "See `GenEvent.swap_mon_handler/5`."
  def swap_mon_handler(plugin, handler1, args1, handler2, args2),
    do:
      Agent.get(
        plugin,
        &GenEvent.swap_mon_handler(&1.event_manager, handler1, args1, handler2, args2)
      )

  @doc "See `GenEvent.which_handlers/1`."
  def which_handlers(plugin), do: Agent.get(plugin, &GenEvent.which_handlers(&1.event_manager))
end
