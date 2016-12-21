import Janus.Util

defmodule Janus do

  def info(url), do: get("#{url}/info")

end
