defmodule EchoWeb.ApproovTokenPlug do

  ##############################################################################
  # Adhere to the Phoenix Module Plugs specification by implementing:
  #   * init/1
  #   * call/2
  #
  # @link https://hexdocs.pm/phoenix/plug.html#module-plugs
  ##############################################################################

  def init(opts), do: opts

  def call(conn, _opts) do
    case ApproovToken.verify_token(conn) do
      {:ok, approov_token_claims} ->
        conn
        |> Plug.Conn.put_private(:approov_token_claims, approov_token_claims)

      {:error, _reason} ->
        conn
        |> _halt_connection()
    end
  end

  # When the Approov token validation fails we return a `401` with an empty body,
  # because we don't want to give clues to an attacker about the reason the
  # request failed, and you can go even further by returning a `400`. Feel free
  # to modify as you see fits best your use case.
  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end

end
