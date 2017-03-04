require Logger

import Janus.Util

defmodule Janus.Session do

  @moduledoc """
  Sessions are connections to the Janus server to which plugins are attached, and from which events are retrieved.
  """

  @enforce_keys [:id, :base_url, :event_manager]
  defstruct [
    :id,
    :base_url,
    :event_manager,
    handles: %{}
  ]

  @doc "Creates a `Session` with the server at `url`."

  def start(url) do
    name = make_ref()
    {:ok, _pid} = Supervisor.start_child(Janus.Session.Supervisor, [url, name])
    {:ok, name}
  end

  def start_link(url, name) do
    case post(url, %{janus: :create}) do
      {:ok, body} ->
        id = body.data.id
        {:ok, event_manager} = GenEvent.start_link()
        session = %Janus.Session{
          id: id,
          base_url: "#{url}/#{id}",
          event_manager: event_manager
        }
        {:ok, pid} = Agent.start_link(fn -> session end, name: {:global, name})
        spawn_link(fn () -> poll(name) end)
        {:ok, pid}
      v -> v
    end
  end

  @doc """
  Attaches the plugin identified by `id` to the specified session.

  ## Examples

      {:ok, session} = Janus.Session.start("http://localhost:8088/janus")
      session |> Janus.Session.attach_plugin("janus.plugin.echotest")
  """

  def attach_plugin(session, id) do
    base_url = Agent.get({:global, session}, &(&1.base_url))
    v = case post(base_url, %{janus: :attach, plugin: id}) do
      {:ok, body} ->
        id = body.data.id
        {:ok, event_manager} = GenEvent.start_link()
        plugin = %Janus.Plugin{
          id: id,
          base_url: "#{base_url}/#{id}",
          event_manager: event_manager
        }
        name = make_ref()
        {:ok, plugin_pid} = Supervisor.start_child(Janus.Plugin.Supervisor, [plugin, name])
        Agent.update {:global, session}, fn(s) ->
          new_handles = Map.put(s.handles, id, plugin_pid)
          %{ s | handles: new_handles}
        end
        {:ok, name}
      v -> v
    end
    v
  end

  @doc "Destroys the session, detaching all plugins, and freeing all allocated resources."

  def destroy(session) do
    base_url = Agent.get({:global, session}, &(&1.base_url))
    plugin_pids = Agent.get({:global, session}, &(&1.handles)) |> Map.values()
    Enum.each (plugin_pids), &(Janus.Plugin.detach(&1))
    Agent.stop({:global, session})
    post(base_url, %{janus: :destroy})
  end

  @doc "See `GenEvent.add_handler/3`."
  def add_handler(session, handler, args), do: Agent.get {:global, session}, &(GenEvent.add_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.add_mon_handler/3`."
  def add_mon_handler(session, handler, args), do: Agent.get {:global, session}, &(GenEvent.add_mon_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.call/4`."
  def call(session, handler, timeout, request \\ 5000), do: Agent.get {:global, session}, &(GenEvent.call(&1.event_manager, handler, request, timeout))

  @doc "See `GenEvent.remove_handler/3`."
  def remove_handler(session, handler, args), do: Agent.get {:global, session}, &(GenEvent.remove_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.stream/2`."
  def stream(session, options \\ []), do: Agent.get {:global, session}, &(GenEvent.stream(&1.event_manager, options))

  @doc "See `GenEvent.swap_handler/5`."
  def swap_handler(session, handler1, args1, handler2, args2), do: Agent.get {:global, session}, &(GenEvent.swap_handler(&1.event_manager, handler1, args1, handler2, args2))

  @doc "See `GenEvent.swap_mon_handler/5`."
  def swap_mon_handler(session, handler1, args1, handler2, args2), do: Agent.get {:global, session}, &(GenEvent.swap_mon_handler(&1.event_manager, handler1, args1, handler2, args2))

  @doc "See `GenEvent.which_handlers/1`."
  def which_handlers(session), do: Agent.get {:global, session}, &(GenEvent.which_handlers(&1.event_manager))

  defp poll(session) do
    s = Agent.get {:global, session}, &(&1)
    case get(s.base_url) do
      {:ok, data} ->
        event_manager = s.event_manager
        case data do
          %{janus: "keepalive"} -> GenEvent.notify(event_manager, {:keepalive, session})
          %{sender: sender} ->
            # Refetch the session in case we've added new plugins while this poll was in flight.
            s = Agent.get {:global, session}, &(&1)
            plugin_pid = s.handles[sender]
            if plugin_pid do
              case data do
                %{janus: "event", plugindata: plugindata} ->
                  jsep = data[:jsep]
                  Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:event, session, plugin_pid, plugindata.data, jsep}))
                %{janus: "webrtcup"} -> Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:webrtcup, session, plugin_pid}))
                %{janus: "media", type: type, receiving: receiving} ->
                  Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:media, session, plugin_pid, type, receiving}))
                %{janus: "slowlink", uplink: uplink, nacks: nacks} ->
                  Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:slowlink, session, plugin_pid, uplink, nacks}))
                %{janus: "hangup"} ->
                  reason = data[:reason]
                  Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:hangup, session, plugin_pid, reason}))
                %{janus: "detached"} ->
                  Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:detached, session, plugin_pid}))
              end
            end
          _ -> nil
        end
        poll(session)
      {:error, reason} -> Logger.error(reason)
      {:error, :invalid, _} -> nil
    end
  end

end
