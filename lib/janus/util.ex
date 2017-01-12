require Logger

defmodule Janus.Util do

  @moduledoc false

  def get(url) do
    Logger.debug("GET #{url}")
    case HTTPoison.get(url, [], recv_timeout: :infinity) do
      {:ok, %HTTPoison.Response{body: body}} ->
        case Poison.decode(body, keys: :atoms) do
          {:ok, %{janus: "error", error: error}} ->
            Logger.error(error.reason)
            {:error, error.reason}
          {:error, error} ->
            Logger.error(error)
            {:error, error}
          {:ok, v} ->
            Logger.debug(inspect(v))
            {:ok, v}
        end
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(reason)
        {:error, reason}
    end
  end

  def post(url, body) do
    Logger.debug("POST #{url} (#{inspect(body)})")
    case HTTPoison.post(url, Poison.encode!(add_transaction_id(body))) do
      {:ok, %HTTPoison.Response{body: body}} ->
        case Poison.decode(body, keys: :atoms) do
          {:ok, %{janus: "error", error: error}} ->
            Logger.error(error.reason)
            {:error, error.reason}
          {:error, error} ->
            Logger.error(error)
            {:error, error}
          {:ok, v} ->
            Logger.debug(inspect(v))
            {:ok, v}
        end
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(reason)
        {:error, reason}
    end
  end

  def maybe_add_key(map, _key, nil), do: map
  def maybe_add_key(map, key, value), do: Map.put(map, key, value)

  defp transaction_id, do: :rand.uniform(1000000000) |> to_string

  defp add_transaction_id(body) do
    case Map.get(body, :transaction) do
      nil -> Map.merge(body, %{transaction: transaction_id()})
      _ -> body
    end
  end

end
