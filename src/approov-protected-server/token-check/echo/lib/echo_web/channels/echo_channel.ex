defmodule EchoWeb.EchoChannel do
  use EchoWeb, :channel

  require Logger

  def join("echo:chamber", payload, socket) do
    case _authorized(:join, payload, socket) do
      {:ok, socket} ->
        {:ok, socket}

      _ ->
        {:error, %{reason: "Whoops, something went wrong!"}}
    end
  end

  def handle_in("echo_it", payload, socket) do
    case _authorized(:echo, payload, socket) do
      {:ok, socket} ->

        echo = %{"message" => "#{payload["message"]}, #{payload["message"]}, #{payload["message"]}..."}
        broadcast(socket, "echo:chamber", echo)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  defp _authorized(action, payload, socket) do
    Logger.info(%{phoenix_channel_action: action})
    Logger.info(%{phoenix_channel_payload: payload})

    # Always perform the Approov token check before the User Authentication.
    with {:ok, _approov_token_claims} <- ApproovToken.verify_token(payload),
         {:ok, current_user} <- Echo.User.authorize(params: payload),
         true <- Echo.User.can_do_action?(action, current_user) do
      {:ok, socket}
    else
      {:error, reason} ->
        _log_error(reason)
        :error

      false ->
        _log_error("User cannot perform the action: #{action}")
        :error
    end
  end

  defp _log_error(reason) when is_atom(reason), do: Logger.warn(Atom.to_string(reason))
  defp _log_error(reason), do: Logger.warn(reason)
end
