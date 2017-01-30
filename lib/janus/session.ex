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

  @doc """
  Creates an unstarted session with the server at `url`.

  Note that if `start/1` is not called within the session timeout, then the session will be invalid.
  Use this function if you must perform additional configuration steps before the session is started.
  """

  def init(url) do
    case post(url, %{janus: :create}) do
      {:ok, body} ->
        id = body.data.id
        {:ok, event_manager} = GenEvent.start_link()
        session = %Janus.Session{
          id: id,
          base_url: "#{url}/#{id}",
          event_manager: event_manager
        }
        Agent.start(fn -> session end)
      v -> v
    end
  end

  @doc "Starts an existing session previously created via `init/1`."

  def start(pid) when is_pid(pid), do: poll(pid)

  def start(url) do
    case init(url) do
      {:ok, pid} ->
        start(pid)
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

  def attach_plugin(pid, id) do
    base_url = Agent.get(pid, &(&1.base_url))
    v = case post(base_url, %{janus: :attach, plugin: id}) do
      {:ok, body} ->
        id = body.data.id
        {:ok, event_manager} = GenEvent.start_link()
        plugin = %Janus.Plugin{
          id: id,
          base_url: "#{base_url}/#{id}",
          event_manager: event_manager
        }
        {:ok, plugin_pid} = Agent.start(fn -> plugin end)
        Agent.update pid, fn(session) ->
          new_handles = Map.put(session.handles, id, plugin_pid)
          %{ session | handles: new_handles}
        end
        {:ok, plugin_pid}
      v -> v
    end
    v
  end

  @doc "Destroys the session, detaching all plugins, and freeing all allocated resources."

  def destroy(pid) do
    base_url = Agent.get(pid, &(&1.base_url))
    plugin_pids = Agent.get(pid, &(&1.handles)) |> Map.values()
    Enum.each (plugin_pids), &(Janus.Plugin.detach(&1))
    Agent.stop(pid)
    post(base_url, %{janus: :destroy})
  end

  @doc "See `GenEvent.add_handler/3`."
  def add_handler(session, handler, args), do: Agent.get session, &(GenEvent.add_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.add_mon_handler/3`."
  def add_mon_handler(session, handler, args), do: Agent.get session, &(GenEvent.add_mon_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.call/4`."
  def call(session, handler, timeout, request \\ 5000), do: Agent.get session, &(GenEvent.call(&1.event_manager, handler, request, timeout))

  @doc "See `GenEvent.remove_handler/3`."
  def remove_handler(session, handler, args), do: Agent.get session, &(GenEvent.remove_handler(&1.event_manager, handler, args))

  @doc "See `GenEvent.stream/2`."
  def stream(session, options \\ []), do: Agent.get session, &(GenEvent.stream(&1.event_manager, options))

  @doc "See `GenEvent.swap_handler/5`."
  def swap_handler(session, handler1, args1, handler2, args2), do: Agent.get session, &(GenEvent.swap_handler(&1.event_manager, handler1, args1, handler2, args2))

  @doc "See `GenEvent.swap_mon_handler/5`."
  def swap_mon_handler(session, handler1, args1, handler2, args2), do: Agent.get session, &(GenEvent.swap_mon_handler(&1.event_manager, handler1, args1, handler2, args2))

  @doc "See `GenEvent.which_handlers/1`."
  def which_handlers(session), do: Agent.get session, &(GenEvent.which_handlers(&1.event_manager))

  defp poll(pid) do
    session = Agent.get pid, &(&1)
    spawn fn ->
      case get(session.base_url) do
        {:ok, data} ->
          event_manager = session.event_manager
          case data do
            %{janus: "keepalive"} -> GenEvent.notify(event_manager, {:keepalive, pid})
            %{sender: sender} ->
              # Refetch the session in case we've added new plugins while this poll was in flight.
              session = Agent.get pid, &(&1)
              plugin_pid = session.handles[sender]
              if plugin_pid do
                case data do
                  %{janus: "event", plugindata: plugindata} ->
                    jsep = data[:jsep]
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:event, pid, plugin_pid, plugindata.data, jsep}))
                  %{janus: "webrtcup"} -> Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:webrtcup, pid, plugin_pid}))
                  %{janus: "media", type: type, receiving: receiving} ->
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:media, pid, plugin_pid, type, receiving}))
                    if (receiving == false) do
                      Janus.Plugin.detach(plugin_pid)
                    end
                  %{janus: "slowlink", uplink: uplink, nacks: nacks} ->
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:slowlink, pid, plugin_pid, uplink, nacks}))
                  %{janus: "hangup"} ->
                    reason = data[:reason]
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:hangup, pid, plugin_pid, reason}))
                  %{janus: "detached"} ->
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:detached, pid, plugin_pid}))
                end
              end
            _ -> nil
          end
          poll(pid)
        {:error, reason} -> Logger.error(reason)
        {:error, :invalid, _} -> nil
      end
    end
  end

end
