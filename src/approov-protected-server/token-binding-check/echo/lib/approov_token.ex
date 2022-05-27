defmodule ApproovToken do
  require Logger

  use Joken.Config

  @impl Joken.Config
  def token_config, do: default_claims(skip: [:aud, :iat, :iss, :jti, :nbf])

  # Verifies the token from an HTTP request or from a Websockets connection/event
  def verify_token(params) do
    with {:ok, approov_token} <- _get_approov_token(params),
         {:ok, approov_token_claims} <- _decode_and_verify(approov_token) do

      {:ok, approov_token_claims}
    else
      {:error, reason} ->
        Logger.info(%{approov_token_error: reason})
        {:error, reason}
    end
  end


  ########################
  # APPROOV TOKEN FETCH
  ########################

  # For when the Approov token is the header of a regular HTTP Request
  defp _get_approov_token(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "x-approov-token") do
      [] ->
        Logger.info("Approov token not in the headers. Next, try to retrieve from url query params.")
        Logger.info(%{headers: conn.req_headers, params: conn.params})
        _get_approov_token(conn.params)

      [approov_token | _] ->
        {:ok, approov_token}
    end
  end

  # Fetch for a Phoenix Channel event, where the token is provided in the event
  # payload.
  defp _get_approov_token(%{"x-approov-token" => approov_token}), do: {:ok, approov_token}
  defp _get_approov_token(%{"X-Approov-Token" => approov_token}), do: {:ok, approov_token}

  # Catch failure to fetch the Approov token from the WebSocket upgrade request
  # or from the Phoenix Channel event.
  defp _get_approov_token(_params) do
    {:error, :missing_approov_token}
  end


  ########################
  # APPROOV TOKEN CHECK
  ########################

  defp _decode_and_verify(approov_token) do
    secret = Application.fetch_env!(:echo, ApproovToken)[:secret_key]

    # call `verify_and_validate/2` injected by `use Joken.Config`
    case verify_and_validate(approov_token, Joken.Signer.create("HS256", secret)) do
      {:ok, %{"exp" => _expiration}} = result ->
        result

      # The library only checks the `exp` when present, and verifies successfully
      # without it, and doesn't have an option to enforce it.
      {:ok, _claims} ->
        {:error, :missing_expiration_time}

      result ->
        result
    end
  end


  ################################
  # APPROOV TOKEN BINDING CHECK
  ################################

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

  defp _verify_approov_token_binding(_approov_token_claims, _token_binding_header) do
    {:error, :approov_token_missing_pay_claim}
  end

end
