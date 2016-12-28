import Janus.Util

defmodule Janus.Plugin do

  @enforce_keys [:id, :base_url, :event_manager]
  defstruct [
    :id,
    :base_url,
    :event_manager
  ]

  def message(pid, body, jsep \\ nil) do
    plugin = Agent.get(pid, &(&1))
    msg = %{body: body}
    if jsep, do: Map.put(msg, :jsep, jsep)
    post(plugin.base_url, msg)
  end

  def hangup(pid) do
    plugin = Agent.get(pid, &(&1))
    case post(plugin.base_url, %{janus: :hangup}) do
      {:ok, _} -> :ok
      v -> v
    end
  end

  def trickle(pid, candidates \\ nil) do
    msg = %{janus: :trickle}
    case candidates do
      nil -> Map.set(msg, :candidate, %{completed: true})
      v when is_list(v) -> Map.set(msg, :candidates, v)
      v when is_map(v) -> Map.set(msg, :candidate, v)
    end
    plugin = Agent.get(pid, &(&1))
    post(plugin.base_url, msg)
  end

  def add_handler(plugin, handler, args), do: Agent.get plugin, &(GenEvent.add_handler(&1.event_manager, handler, args))

  def add_mon_handler(plugin, handler, args), do: Agent.get plugin, &(GenEvent.add_mon_handler(&1.event_manager, handler, args))

  def call(plugin, handler, timeout, request \\ 5000), do: Agent.get plugin, &(GenEvent.call(&1.event_manager, handler, request, timeout))

  def remove_handler(plugin, handler, args), do: Agent.get plugin, &(GenEvent.remove_handler(&1.event_manager, handler, args))

  def stream(plugin, options \\ []), do: Agent.get plugin, &(GenEvent.stream(&1.event_manager, options))

  def swap_handler(plugin, handler1, args1, handler2, args2), do: Agent.get plugin, &(GenEvent.swap_handler(&1.event_manager, handler1, args1, handler2, args2))

  def swap_mon_handler(plugin, handler1, args1, handler2, args2), do: Agent.get plugin, &(GenEvent.swap_mon_handler(&1.event_manager, handler1, args1, handler2, args2))

  def which_handlers(plugin), do: Agent.get plugin, &(GenEvent.which_handlers(&1.event_manager))

end
