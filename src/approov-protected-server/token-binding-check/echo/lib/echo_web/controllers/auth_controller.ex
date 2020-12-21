defmodule EchoWeb.AuthController do

  use EchoWeb, :controller

  def register(conn, params) do
    case Echo.User.create(params) do
      {:ok, user} ->
        json(conn, %{id: user.uid})

      {:error, _reason} ->
        json(conn, %{error: "Failed to create user"})
    end
  end

  def login(conn, params) do
    case Echo.User.authenticate(params) do
      {:ok, user} ->
        json(conn, %{token: user.token})

      {:error, _reason} ->
        json(conn, %{error: "Failed to authenticate user"})
    end
  end
end
