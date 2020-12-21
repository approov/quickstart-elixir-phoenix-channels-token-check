defmodule EchoWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  ## Channels
  channel "echo:chamber", EchoWeb.EchoChannel

  @impl true
  def connect(params, socket, _connect_info) do
    Logger.info(%{socket_connect_params: params})

    socket
    |> _authorize(params)
  end

  @impl true
  def id(_socket), do: nil

  defp _authorize(socket, params) do
    # Add your user authentication logic here as you see fit. For example:
    with {:ok, current_user} <- Echo.User.authorize(params: params) do
      socket = Phoenix.Socket.assign(socket, context: %{current_user: current_user})

      {:ok, socket}
    else
      {:error, reason} ->
        _log_error(reason)
        :error
    end
  end

  defp _log_error(reason) when is_atom(reason), do: Logger.warn(Atom.to_string(reason))
  defp _log_error(reason), do: Logger.warn(reason)

end
