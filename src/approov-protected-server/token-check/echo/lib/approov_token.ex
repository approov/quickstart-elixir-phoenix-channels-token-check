defmodule ApproovToken do
  require Logger

  def verify(%Plug.Conn{} = conn, %{} = approov_jwk) do
    with {:ok, approov_token} <- _get_approov_token_header(conn),
         {:ok, approov_token_claims} <- _verify_approov_token(approov_token, approov_jwk) do

      {:ok, approov_token_claims}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify(%{} = params, %{} = approov_jwk) do
    with {:ok, approov_token} <- _get_approov_token(params),
         {:ok, approov_token_claims} <- _verify_approov_token(approov_token, approov_jwk) do

      {:ok, approov_token_claims}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp _get_approov_token_header(conn) do
    case Plug.Conn.get_req_header(conn, "x-approov-token") do
      [] ->
        Logger.info("Approov token not in the headers. Next, try to retrieve from url query params.")
        _get_approov_token(conn.params)

      [approov_token | _] ->

        {:ok, approov_token}
    end
  end

  defp _get_approov_token(%{x_headers: x_headers}) when is_list(x_headers) do
    case Utils.filter_list_of_tuples(x_headers, "x-approov-token") do
      nil ->
        {:ok, Utils.filter_list_of_tuples(x_headers, "X-Approov-Token")}

      approov_token ->
        {:ok, approov_token}
    end
  end

  defp _get_approov_token(%{"x-approov-token" => approov_token}), do: {:ok, approov_token}
  defp _get_approov_token(%{"X-Approov-Token" => approov_token}), do: {:ok, approov_token}
  defp _get_approov_token(_params), do: {:error, :missing_approov_token}

  defp _verify_approov_token(approov_token, approov_jwk) do
    with {:ok, approov_token_claims} <- _decode_and_verify(approov_token, approov_jwk),
         true <- _has_expiration_claim?(approov_token_claims),
         :ok <- _verify_expiration(approov_token_claims) do
      {:ok, approov_token_claims}
    else
      {:error, reason} ->
        {:error, reason}

      false ->
        {:error, :approov_token_missing_expiration_claim}
    end
  end

  defp _decode_and_verify(approov_token, approov_jwk) do
    case JOSE.JWT.verify_strict(approov_jwk, ["HS256"], approov_token) do
      {true, approov_token_claims, _jws} ->
        {:ok, approov_token_claims}

      {false, _approov_token_claims, _jws} ->
        {:error, :approov_token_invalid_signature}

      {:error, {:badarg, _arg}} ->
        {:error, :approov_token_malformed}

      {:error, _reason} ->
        {:error, :jwt_library_internal_error}
    end
  end

  defp _has_expiration_claim?(%JOSE.JWT{fields: %{"exp" => _exp}}), do: true
  defp _has_expiration_claim?(_approov_token_claims), do: false

  defp _verify_expiration(%JOSE.JWT{fields: %{"exp" => timestamp}}) do
    datetime = _timestamp_to_datetime(timestamp)
    now = DateTime.utc_now()

    case DateTime.compare(now, datetime) do
      :lt ->
        :ok

      _ ->
        {:error, :approov_token_expired}
    end
  end

  defp _timestamp_to_datetime(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end

  defp _timestamp_to_datetime(timestamp) when is_float(timestamp) do
    # iex> Integer.parse "1555083349.3777623"
    # {1555083349, ".3777623"}
    {timestamp, _decimals} = Integer.parse("#{timestamp}")
    DateTime.from_unix!(timestamp)
  end
end
