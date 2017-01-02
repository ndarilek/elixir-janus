defmodule Janus.Bypass do

  def endpoint_url(bypass), do: "http://localhost:#{bypass.port}/janus"

end
