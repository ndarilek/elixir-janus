defmodule Janus.Plugin.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      worker(Janus.Plugin, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

end
