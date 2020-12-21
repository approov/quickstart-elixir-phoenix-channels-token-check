defmodule EchoWeb.EchoController do
  use EchoWeb, :controller

  def show(conn, _params) do
    json(conn, %{message: "Hello, World!"})
  end
end
