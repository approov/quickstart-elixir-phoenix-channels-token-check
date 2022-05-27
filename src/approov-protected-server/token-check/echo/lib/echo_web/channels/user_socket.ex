defmodule EchoWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  ## Channels
  channel "echo:chamber", EchoWeb.EchoChannel

  @impl true
  def connect(params, socket, connect_info) do
    Logger.info(%{socket_connect_params: params})
    Logger.info(%{socket_connect_info: connect_info})

    socket
    |> _authorize(params, connect_info)
  end

  @impl true
  def id(_socket), do: nil

  defp _authorize(socket, params, connect_info) do

    headers = Map.merge(params, connect_info)

    # Always perform the Approov token check before the User Authentication.
    with {:ok, _approov_token_claims} <- ApproovToken.verify_token(headers),
         {:ok, current_user} <- Echo.User.authorize(params: params) do

      socket = Phoenix.Socket.assign(socket, context: %{current_user: current_user})

      {:ok, socket}
    else
      {:error, _reason} ->
        :error
    end
  end
end
