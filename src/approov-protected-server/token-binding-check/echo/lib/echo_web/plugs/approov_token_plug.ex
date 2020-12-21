defmodule EchoWeb.ApproovTokenPlug do
  require Logger

  ##############################################################################
  # Adhere to the Phoenix Module Plugs specification by implementing:
  #   * init/1
  #   * call/2
  #
  # @link https://hexdocs.pm/phoenix/plug.html#module-plugs
  ##############################################################################

  # Don't use this function to init the Plug with the Approov secret, because
  # this is only evaluated at compile time, and we don't want the to have
  # secrets inside a release. Secrets must always be retrieved from the
  # environment where the release is running.
  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info(%{http_request_headers: conn.req_headers})
    Logger.info(%{http_request_params: conn.params})

    # Check the `init/1` comment to see why we don't do it there.
    approov_jwk = %{
      "kty" => "oct",
      "k" =>  Utils.fetch_from_env!(:echo, ApproovToken, :secret_key, 64, :string)
    }

    with {:ok, approov_token_claims} <- ApproovToken.verify(conn, approov_jwk) do
      conn
      |> Plug.Conn.put_private(:approov_token_claims, approov_token_claims)
    else
      {:error, reason} ->
        # Logs are set to :debug level, aka for development. Customize it for your needs.
        _log_error(reason)

        conn
        |> _halt_connection()
    end
  end

  defp _log_error(reason) when is_atom(reason), do: Logger.warn(Atom.to_string(reason))
  defp _log_error(reason), do: Logger.warn(reason)

  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end
end
