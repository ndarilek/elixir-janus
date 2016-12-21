import Janus.Util

defmodule Janus.Plugin do

  @enforce_keys [:id, :base_url]
  defstruct [
    :id,
    :base_url,
    :callbacks,
  ]

  def message(pid, body, jsep \\ nil) do
    Agent.get pid, fn(plugin) ->
      msg = %{body: body}
      if jsep, do: Map.put(msg, :jsep, jsep)
      post(plugin.base_url, msg)
    end
  end

  def hangup(pid) do
    Agent.get pid, fn(plugin) ->
      case post(plugin.base_url, %{janus: :hangup}) do
        {:ok, _} -> :ok
        v -> v
      end
    end
  end

  defmacro __using__(_) do
    quote do
      def handle_event(pid, data, jsep \\ nil), do: nil
      defoverridable [handle_event: 3]
    end
  end

end
