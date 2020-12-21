defmodule ApproovToken do
  require Logger

  require Plug.Conn

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

  def verify_token_binding(%Plug.Conn{private: %{approov_token_claims: approov_token_claims}} = conn) do
    with {:ok, token_binding_header} <- _get_token_binding_header(conn),
         :ok <- _verify_approov_token_binding(approov_token_claims, token_binding_header)
    do
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def verify_token_binding(approov_token_claims, %{} = params) do
    with {:ok, token_binding_header} <- _get_token_binding(params),
         :ok <- _verify_approov_token_binding(approov_token_claims, token_binding_header)
    do
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp _get_token_binding_header(%Plug.Conn{} = conn) do
    # We use the Authorization token, but feel free to use another header in
    # the request. Bear in mind that it needs to be the same header used in the
    # mobile app to bind the request with the Approov token.
    case Plug.Conn.get_req_header(conn, "authorization") do
      [] ->
        Logger.info("Approov token binding header is missing. Next, try to retrieve from the url query params.")
        _get_token_binding(conn.params)

      [token_binding_header | _] ->

        {:ok, token_binding_header}
    end
  end

  defp _get_token_binding(%{"Authorization" => token}) when is_binary(token), do: {:ok, token}
  defp _get_token_binding(_params), do: {:error, :missing_approov_token_binding}

  defp _verify_approov_token_binding(
          %JOSE.JWT{fields: %{"pay" => token_binding_claim}} = _approov_token_claims,
         token_binding_header
       )
  do
    # We need to hash and base64 encode the token binding header, because that's
    # how it was included in the Approov token on the mobile app.
    token_binding_header_encoded =
      :crypto.hash(:sha256, token_binding_header)
      |> Base.encode64()

    case token_binding_claim === token_binding_header_encoded do
      true ->
        :ok

      false ->
        {:error, :approov_invalid_token_binding_header}
    end
  end

  # Note that the `pay` claim will, under normal circumstances, be present,
  # but if the Approov failover system is enabled, then no claim will be
  # present, and in this case you want to return true, otherwise you will not
  # be able to benefit from the redundancy afforded by the failover system.
  defp _verify_approov_token_binding(_approov_token_claims, _token_binding_header) do
    # You may want to add some logging here
    Logger.warn("Missing the `pay` claim in the Approov token.")
    :ok
  end
end
