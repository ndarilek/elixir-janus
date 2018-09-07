import Janus.Util

defmodule Janus do
  @moduledoc """
  This library is a client for the [Janus REST API](https://janus.conf.meetecho.com/docs/rest.html).
  """

  @doc """
  Retrieves details on the Janus server located at `url`
  """

  def info(url), do: get("#{url}/info", "")
end
