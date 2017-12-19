require Logger

defmodule Janus.Util do
  @moduledoc false

  def get(url, cookie) do
    Logger.debug("GET #{url}")

    headers =
      if cookie do
        [{"Cookie", cookie}]
      else
        []
      end

    options = [{:recv_timeout, :infinity}]

    case HTTPoison.get(url, headers, options) do
      {:ok, %HTTPoison.Response{body: body, headers: headers}} ->
        case Poison.decode(body, keys: :atoms) do
          {:ok, %{janus: "error", error: error}} ->
            Logger.error(error.reason)
            {:error, error.reason}

          {:error, error} ->
            Logger.error(error)
            {:error, error}

          {:ok, v} ->
            cookie = get_cookie_from_headers(headers)

            Logger.debug(inspect(v))
            {:ok, v, cookie}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(reason)
        {:error, reason}
    end
  end

  def post(url, cookie, body) do
    Logger.debug("POST #{url} (#{inspect(body)})")

    headers =
      if cookie do
        [{"Cookie", cookie}]
      else
        []
      end

    case HTTPoison.post(
           url,
           Poison.encode!(add_transaction_id(body)),
           headers
         ) do
      {:ok, %HTTPoison.Response{body: body, headers: headers}} ->
        case Poison.decode(body, keys: :atoms) do
          {:ok, %{janus: "error", error: error}} ->
            Logger.error(error.reason)
            {:error, error.reason}

          {:error, error} ->
            Logger.error(error)
            {:error, error}

          {:ok, v} ->
            cookie = get_cookie_from_headers(headers)
            Logger.debug(inspect(v))
            {:ok, v, cookie}
        end

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error(reason)
        {:error, reason}
    end
  end

  def maybe_add_key(map, _key, nil), do: map
  def maybe_add_key(map, key, value), do: Map.put(map, key, value)

  defp transaction_id, do: :rand.uniform(1_000_000_000) |> to_string

  defp add_transaction_id(body) do
    case Map.get(body, :transaction) do
      nil -> Map.merge(body, %{transaction: transaction_id()})
      _ -> body
    end
  end

  defp get_cookie_from_headers(headers) do
    cookies =
      Enum.filter(headers, fn
        {"Set-Cookie", _} -> true
        _ -> false
      end)

    if cookies != [] do
      cookie = List.first(cookies)
      elem(cookie, 1)
    else
      nil
    end
  end
end
