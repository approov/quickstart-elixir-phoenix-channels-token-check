defmodule EchoWeb.ApproovTokenBindingPlug do
  require Logger

  ##############################################################################
  # Adhere to the Phoenix Module Plugs specification by implementing:
  #   * init/1
  #   * call/2
  #
  # @link https://hexdocs.pm/phoenix/plug.html#module-plugs
  ##############################################################################

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.info(%{http_request_headers: conn.req_headers})
    Logger.info(%{http_request_params: conn.params})

    with :ok <- ApproovToken.verify_token_binding(conn) do
      conn
    else
      {:error, reason} ->
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
