require Logger

import Janus.Util

defmodule Janus.Session do

  @enforce_keys [:id, :base_url]
  defstruct [
    :id,
    :base_url,
    :callbacks,
    handles: %{}
  ]

  def start(url, callbacks \\ nil) do
    case post(url, %{janus: :create}) do
      {:ok, body} ->
        id = body.data.id
        session = %Janus.Session{
          id: id,
          base_url: "#{url}/#{id}",
          callbacks: callbacks
        }
        {:ok, pid} = Agent.start(fn -> session end)
        poll(pid, session)
        {:ok, pid}
      v -> v
    end
  end

  def attach_plugin(pid, id, callbacks \\ nil) do
    base_url = Agent.get(pid, &(&1.base_url))
    v = case post(base_url, %{janus: :attach, plugin: id}) do
      {:ok, body} ->
        id = body.data.id
        plugin = %Janus.Plugin{
          id: id,
          base_url: "#{base_url}/#{id}",
          callbacks: callbacks
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

  defmacro __using__(_) do
    quote do
      def handle_keepalive(pid), do: nil
      defoverridable [handle_keepalive: 1]
    end
  end

  defp poll(pid, session) do
    spawn fn ->
      case get(session.base_url) do
        {:ok, data} ->
          if session.callbacks do
            case data do
              %{janus: "keepalive"} -> session.callbacks.handle_keepalive(pid)
              %{janus: "event", sender: sender, plugindata: plugindata} ->
                plugin_pid = session.handles[sender]
                if plugin_pid do
                  jsep = data[:jsep]
                  session.callbacks.handle_event(plugin_pid, plugindata.data, jsep)
                end
              %{janus: "webrtcup", sender: sender} ->
                plugin_pid = session.handles[sender]
                if plugin_pid do
                  session.callbacks.handle_webrtcup(plugin_pid)
                end
              %{janus: "media", sender: sender, type: type, receiving: receiving} ->
                plugin_pid = session.handles[sender]
                if plugin_pid do
                  session.callbacks.handle_media(plugin_pid, type, receiving)
                end
              %{janus: "slowlink", sender: sender, uplink: uplink, nacks: nacks} ->
                plugin_pid = session.handles[sender]
                if plugin_pid do
                  session.callbacks.handle_slowlink(plugin_pid, uplink, nacks)
                end
              %{janus: "hangup", sender: sender} ->
                plugin_pid = session.handles[sender]
                if plugin_pid do
                  reason = data[:reason]
                  session.callbacks.handle_hangup(plugin_pid, reason)
                end
              _ -> nil
            end
          end
          poll(pid, session)
        {:error, reason} -> Logger.error(reason)
        {:error, :invalid, _} -> nil
      end
    end
  end

end
