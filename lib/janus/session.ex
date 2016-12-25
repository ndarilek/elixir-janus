require Logger

import Janus.Util

defmodule Janus.Session do

  @enforce_keys [:id, :base_url, :event_manager]
  defstruct [
    :id,
    :base_url,
    :event_manager,
    handles: %{}
  ]

  def start(url, args \\ []) do
    case post(url, %{janus: :create}) do
      {:ok, body} ->
        id = body.data.id
        {:ok, event_manager} = GenEvent.start_link()
        session = %Janus.Session{
          id: id,
          base_url: "#{url}/#{id}",
          event_manager: event_manager
        }
        {:ok, pid} = Agent.start(fn -> session end)
        if args[:start_polling] == nil or args[:start_polling] do
          start_polling(pid)
        end
        {:ok, pid}
      v -> v
    end
  end

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

  def detach(pid) do
    Agent.get(pid, &(post(&1.base_url, %{janus: :detach})))
    Agent.stop(pid)
  end

  def destroy(pid) do
    base_url = Agent.get(pid, &(&1.base_url))
    plugin_pids = Agent.get(pid, &(&1.handles)) |> Map.values()
    plugin_pids.each(&(detach(&1)))
    Agent.stop(pid)
    post(base_url, %{janus: :destroy})
  end

  def add_handler(session, handler, args), do: Agent.get session, &(GenEvent.add_handler(&1.event_handler, handler, args))

  def add_mon_handler(session, handler, args), do: Agent.get session, &(GenEvent.add_mon_handler(&1.event_handler, handler, args))

  def call(session, handler, timeout, request \\ 5000), do: Agent.get session, &(GenEvent.call(&1.event_handler, handler, request, timeout))

  def remove_handler(session, handler, args), do: Agent.get session, &(GenEvent.remove_handler(&1.event_handler, handler, args))

  def stream(session, options \\ []), do: Agent.get session, &(GenEvent.stream(&1.event_handler, options))

  def swap_handler(session, handler1, args1, handler2, args2), do: Agent.get session, &(GenEvent.swap_handler(&1.event_handler, handler1, args1, handler2, args2))

  def swap_mon_handler(session, handler1, args1, handler2, args2), do: Agent.get session, &(GenEvent.swap_mon_handler(&1.event_handler, handler1, args1, handler2, args2))

  def which_handlers(session), do: Agent.get session, &(GenEvent.which_handlers(&1.event_handler))

  def start_polling(pid) do
    session = Agent.get pid, &(&1)
    spawn fn ->
      case get(session.base_url) do
        {:ok, data} ->
          event_manager = session.event_manager
          case data do
            %{janus: "keepalive"} -> GenEvent.notify(event_manager, {:keepalive})
            %{sender: sender} ->
              plugin_pid = session.handles[sender]
              if plugin_pid do
                case data do
                  %{janus: "event", plugindata: plugindata} ->
                    jsep = data[:jsep]
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:event, plugindata.data, jsep}))
                  %{janus: "webrtcup"} -> Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:webrtcup}))
                  %{janus: "media", type: type, receiving: receiving} -> Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:media, type, receiving}))
                  %{janus: "slowlink", uplink: uplink, nacks: nacks} -> Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:slowlink, uplink, nacks}))
                  %{janus: "hangup"} ->
                    reason = data[:reason]
                    Agent.get plugin_pid, &(GenEvent.notify(&1.event_manager, {:hangup, reason}))
                end
              end
            _ -> nil
          end
          start_polling(pid)
        {:error, reason} -> Logger.error(reason)
        {:error, :invalid, _} -> nil
      end
    end
  end

end
