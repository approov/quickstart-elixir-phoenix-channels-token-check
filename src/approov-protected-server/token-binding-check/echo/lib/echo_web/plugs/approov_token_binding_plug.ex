defmodule EchoWeb.ApproovTokenBindingPlug do

  ##############################################################################
  # Adhere to the Phoenix Module Plugs specification by implementing:
  #   * init/1
  #   * call/2
  #
  # @link https://hexdocs.pm/phoenix/plug.html#module-plugs
  ##############################################################################

  def init(opts), do: opts

  def call(conn, _opts) do
    case ApproovToken.verify_token_binding(conn) do
      :ok ->
        conn

      {:error, _reason} ->
        conn
        |> _halt_connection()
    end
  end

  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end
end
