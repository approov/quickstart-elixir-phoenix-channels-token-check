defmodule ApproovQuickstart.ProtectedRoutes do
  @moduledoc false

  @protected_routes [
    %{method: :get, path: "/token-check", action: :token_check, binding: :none},
    %{method: :get, path: "/token-binding", action: :token_binding, binding: :single},
    %{method: :get, path: "/token-double-binding", action: :token_double_binding, binding: :double}
  ]

  def all, do: @protected_routes

  def protected_path?(path) do
    Enum.any?(@protected_routes, &(&1.path == path))
  end

  def binding_for(path) do
    case Enum.find(@protected_routes, &(&1.path == path)) do
      %{binding: binding} -> binding
      _ -> :none
    end
  end
end

defmodule ApproovQuickstart.ApproovState do
  @moduledoc false

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{approov_enabled: true, token_binding_enabled: true} end, name: __MODULE__)
  end

  def approov_enabled? do
    Agent.get(__MODULE__, & &1.approov_enabled)
  end

  def token_binding_enabled? do
    Agent.get(__MODULE__, & &1.token_binding_enabled)
  end

  def enable_approov do
    Agent.update(__MODULE__, fn _ -> %{approov_enabled: true, token_binding_enabled: true} end)
  end

  def disable_approov do
    Agent.update(__MODULE__, fn _ -> %{approov_enabled: false, token_binding_enabled: false} end)
  end

  def enable_token_binding do
    Agent.update(__MODULE__, &Map.put(&1, :token_binding_enabled, true))
  end

  def disable_token_binding do
    Agent.update(__MODULE__, &Map.put(&1, :token_binding_enabled, false))
  end

  def state do
    %{
      approovEnabled: approov_enabled?(),
      tokenBindingEnabled: token_binding_enabled?()
    }
  end
end

defmodule ApproovQuickstart.ApproovToken do
  @moduledoc false

  require Logger

  use Joken.Config

  @approov_header "approov-token"
  @auth_header "authorization"
  @session_id_header "sessionid"
  @missing_secret_placeholder "approov_base64url_secret_here"

  @impl Joken.Config
  def token_config, do: default_claims(skip: [:aud, :iat, :iss, :jti, :nbf])

  def verify_token(%Plug.Conn{} = conn) do
    with {:ok, token} <- fetch_approov_token(conn),
         {:ok, claims} <- verify_token_value(token) do
      {:ok, claims}
    else
      {:error, reason} ->
        Logger.debug(%{approov_token_error: reason})
        {:error, reason}
    end
  end

  def verify_token_value(token) when is_binary(token) do
    log_secret_status()
    trimmed = String.trim(token)

    if trimmed == "" do
      {:error, :missing_approov_token}
    else
      verify_and_decode(trimmed)
    end
  end

  def verify_token_value(_token), do: {:error, :missing_approov_token}

  def verify_binding(%Plug.Conn{} = conn, %{} = claims, binding_mode) do
    with {:ok, binding_value} <- extract_binding_value(conn, binding_mode),
         :ok <- validate_binding(binding_value, claims) do
      :ok
    else
      {:error, reason} ->
        Logger.debug(%{approov_binding_error: reason})
        {:error, reason}
    end
  end

  defp fetch_approov_token(conn) do
    case Plug.Conn.get_req_header(conn, @approov_header) do
      [token | _] when is_binary(token) and byte_size(token) > 0 ->
        {:ok, String.trim(token)}

      _ ->
        {:error, :missing_approov_token}
    end
  end

  defp verify_and_decode(token) do
    signer = Joken.Signer.create("HS256", approov_secret())

    case verify_and_validate(token, signer) do
      {:ok, %{"exp" => _exp} = claims} ->
        {:ok, claims}

      {:ok, _claims} ->
        {:error, :missing_expiration}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp approov_secret do
    case Application.get_env(:approov_quickstart, :approov_secret) do
      secret when is_binary(secret) and byte_size(secret) > 0 -> secret
      _ -> ""
    end
  end

  defp log_secret_status do
    case secret_status() do
      :ok ->
        :ok

      :missing ->
        log_secret_issue("Required secret is not set")

      :invalid ->
        log_secret_issue("Required secret is invalid")
    end
  end

  defp secret_status do
    raw = System.get_env("APPROOV_BASE64URL_SECRET")

    cond do
      raw in [nil, ""] ->
        :missing

      raw == @missing_secret_placeholder ->
        :missing

      match?({:ok, _}, Base.url_decode64(raw, padding: false)) ->
        :ok

      match?({:ok, _}, Base.url_decode64(raw, padding: true)) ->
        :ok

      true ->
        :invalid
    end
  end

  defp log_secret_issue(message) do
    key = {__MODULE__, :secret_issue, message}

    if :persistent_term.get(key, false) do
      :ok
    else
      :persistent_term.put(key, true)
      Logger.error(message)
    end
  end

  def extract_binding_value(conn, binding_mode) do
    headers = binding_headers(binding_mode)

    if headers == [] do
      {:error, :unsupported_binding_mode}
    else
      result =
        Enum.reduce_while(headers, [], fn header, acc ->
          case Plug.Conn.get_req_header(conn, header) do
            [value | _] when is_binary(value) and byte_size(value) > 0 ->
              trimmed = String.trim(value)

              if byte_size(trimmed) > 0 do
                {:cont, [trimmed | acc]}
              else
                {:halt, :missing}
              end

            _ ->
              {:halt, :missing}
          end
        end)

      case result do
        :missing -> {:error, :missing_binding_header}
        values -> {:ok, values |> Enum.reverse() |> Enum.join()}
      end
    end
  end

  defp binding_headers(:single), do: [@auth_header]
  defp binding_headers(:double), do: [@auth_header, @session_id_header]
  defp binding_headers(_binding_mode), do: []

  def validate_binding(binding_value, %{"pay" => expected}) when is_binary(expected) do
    expected = String.trim(expected)
    computed = hash_base64(binding_value)

    if Plug.Crypto.secure_compare(expected, computed) do
      :ok
    else
      {:error, :binding_mismatch}
    end
  end

  def validate_binding(_binding_value, _claims), do: {:error, :missing_pay_claim}

  defp hash_base64(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64()
  end
end

defmodule ApproovQuickstartWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      import Plug.Conn
      plug :accepts, ["json"]
    end
  end

  def router do
    quote do
      use Phoenix.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

defmodule ApproovQuickstartWeb.SocketSerializer.V1 do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.{Broadcast, Message, Reply}
  alias Phoenix.Socket.V1.JSONSerializer, as: V1

  @impl true
  def fastlane!(%Broadcast{} = msg), do: V1.fastlane!(msg)

  @impl true
  def encode!(%Message{} = msg), do: V1.encode!(msg)
  def encode!(%Reply{} = reply), do: V1.encode!(reply)

  @impl true
  def decode!(raw_message, opts) do
    if blank_payload?(raw_message) do
      heartbeat_message()
    else
      V1.decode!(raw_message, opts)
    end
  end

  defp blank_payload?(raw_message) do
    raw_message
    |> IO.iodata_to_binary()
    |> String.trim()
    |> case do
      "" -> true
      _ -> false
    end
  end

  defp heartbeat_message do
    %Message{topic: "phoenix", event: "heartbeat", payload: %{}, ref: "0", join_ref: nil}
  end
end

defmodule ApproovQuickstartWeb.SocketSerializer.V2 do
  @moduledoc false
  @behaviour Phoenix.Socket.Serializer

  alias Phoenix.Socket.{Broadcast, Message, Reply}
  alias Phoenix.Socket.V2.JSONSerializer, as: V2

  @impl true
  def fastlane!(%Broadcast{} = msg), do: V2.fastlane!(msg)

  @impl true
  def encode!(%Message{} = msg), do: V2.encode!(msg)
  def encode!(%Reply{} = reply), do: V2.encode!(reply)

  @impl true
  def decode!(raw_message, opts) do
    if blank_payload?(raw_message) do
      heartbeat_message()
    else
      V2.decode!(raw_message, opts)
    end
  end

  defp blank_payload?(raw_message) do
    raw_message
    |> IO.iodata_to_binary()
    |> String.trim()
    |> case do
      "" -> true
      _ -> false
    end
  end

  defp heartbeat_message do
    %Message{topic: "phoenix", event: "heartbeat", payload: %{}, ref: "0", join_ref: nil}
  end
end

defmodule ApproovQuickstartWeb.RequestLogger do
  @moduledoc false

  require Logger

  alias ApproovQuickstart.ApproovState
  alias ApproovQuickstart.ProtectedRoutes

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.Conn.register_before_send(conn, fn conn ->
      maybe_log(conn)
      conn
    end)
  end

  defp maybe_log(conn) do
    status = conn.status || 0

    if status in [200, 401] do
      state = ApproovState.state()
      required_headers = required_headers(conn, state)
      summary = summary(conn, status, state)
      message = format_log_line(conn, status, state, summary, required_headers)

      case status do
        200 -> Logger.info(message)
        401 -> Logger.warning(message)
      end
    end
  end

  defp summary(conn, 401, _state) do
    case conn.private[:approov_failure_reason] do
      nil -> "approov_failed:unauthorized"
      reason -> "approov_failed:#{format_reason(reason)}"
    end
  end

  defp summary(conn, 200, state) do
    if ProtectedRoutes.protected_path?(conn.request_path) do
      if state.approovEnabled do
        "approov_ok"
      else
        "approov_disabled"
      end
    else
      "unprotected"
    end
  end

  defp required_headers(conn, state) do
    if ProtectedRoutes.protected_path?(conn.request_path) and state.approovEnabled do
      binding_enabled = state.tokenBindingEnabled

      case ProtectedRoutes.binding_for(conn.request_path) do
        :none -> ["Approov-Token"]
        :single when binding_enabled -> ["Approov-Token", "Authorization"]
        :double when binding_enabled -> ["Approov-Token", "Authorization", "SessionId"]
        _ -> ["Approov-Token"]
      end
    else
      []
    end
  end

  defp format_ip(nil), do: "unknown"
  defp format_ip(ip), do: ip |> :inet.ntoa() |> to_string()

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: inspect(reason)

  defp format_log_line(conn, status, state, summary, required_headers) do
    "http.request.completed " <>
      "\"summary\":\"#{summary}\"," <>
      "\"method\":\"#{conn.method}\"," <>
      "\"path\":\"#{conn.request_path}\"," <>
      "\"status\":#{status}," <>
      "\"ip\":\"#{format_ip(conn.remote_ip)}\"," <>
      "\"port\":#{conn.port}, " <>
      format_state(state) <> " " <>
      "\"required_headers\":#{format_headers(required_headers)}"
  end

  defp format_state(state) do
    "{" <>
      "\"approovEnabled\":#{state.approovEnabled}," <>
      "\"tokenBindingEnabled\":#{state.tokenBindingEnabled}" <>
      "}"
  end

  defp format_headers(headers) do
    inner =
      headers
      |> Enum.map(&"\"#{&1}\"")
      |> Enum.join(",")

    "[" <> inner <> "]"
  end
end

defmodule ApproovQuickstart.ApproovRequestVerifier do
  @moduledoc false

  alias ApproovQuickstart.ApproovState
  alias ApproovQuickstart.ApproovToken
  alias ApproovQuickstart.ProtectedRoutes

  @type verify_error ::
          :missing_approov_token
          | :token_verification_failed
          | :missing_binding_header
          | :binding_mismatch
          | :unsupported_binding_mode

  @spec verify_http_request(Plug.Conn.t()) :: {:ok, map()} | {:error, verify_error()} | :skip
  def verify_http_request(%Plug.Conn{} = conn) do
    if ApproovState.approov_enabled?() do
      with {:ok, claims} <- verify_http_token(conn),
           :ok <- verify_http_binding(conn, claims) do
        {:ok, claims}
      end
    else
      :skip
    end
  end

  @spec verify_socket_request(map(), map() | nil) :: {:ok, map()} | {:error, verify_error()} | :skip
  def verify_socket_request(params, connect_info) when is_map(params) do
    safe_connect_info =
      if is_map(connect_info) do
        connect_info
      else
        %{}
      end

    if ApproovState.approov_enabled?() do
      with {:ok, token} <- fetch_socket_token(params, safe_connect_info),
           {:ok, claims} <- verify_socket_token(token),
           :ok <- verify_socket_binding(params, safe_connect_info, claims) do
        {:ok, claims}
      end
    else
      :skip
    end
  end

  defp verify_http_token(conn) do
    case ApproovToken.verify_token(conn) do
      {:ok, claims} -> {:ok, claims}
      {:error, :missing_approov_token} -> {:error, :missing_approov_token}
      {:error, _reason} -> {:error, :token_verification_failed}
    end
  end

  defp verify_socket_token(token) do
    case ApproovToken.verify_token_value(token) do
      {:ok, claims} -> {:ok, claims}
      {:error, :missing_approov_token} -> {:error, :missing_approov_token}
      {:error, _reason} -> {:error, :token_verification_failed}
    end
  end

  defp verify_http_binding(conn, claims) do
    case ProtectedRoutes.binding_for(conn.request_path) do
      :none ->
        :ok

      binding_mode ->
        if ApproovState.token_binding_enabled?() do
          conn
          |> ApproovToken.verify_binding(claims, binding_mode)
          |> normalize_binding_result()
        else
          :ok
        end
    end
  end

  defp verify_socket_binding(params, connect_info, claims) do
    if ApproovState.token_binding_enabled?() do
      with {:ok, binding_value} <- fetch_socket_binding_value(params, connect_info),
           :ok <- ApproovToken.validate_binding(binding_value, claims) do
        :ok
      else
        {:error, reason} -> {:error, normalize_binding_error(reason)}
      end
    else
      :ok
    end
  end

  defp normalize_binding_result(:ok), do: :ok

  defp normalize_binding_result({:error, reason}) do
    {:error, normalize_binding_error(reason)}
  end

  defp normalize_binding_error(:missing_binding_header), do: :missing_binding_header
  defp normalize_binding_error(:binding_mismatch), do: :binding_mismatch
  defp normalize_binding_error(:unsupported_binding_mode), do: :unsupported_binding_mode
  defp normalize_binding_error(_reason), do: :token_verification_failed

  defp fetch_socket_binding_value(params, connect_info) do
    auth_value =
      param_value(params, ["authorization"]) ||
        header_value(connect_info, "authorization")

    session_value =
      param_value(params, ["sessionid", "session_id"]) ||
        header_value(connect_info, "sessionid")

    binding_mode =
      case params["binding"] || params["binding_mode"] do
        "double" -> :double
        "single" -> :single
        _ -> if session_value, do: :double, else: :single
      end

    with {:ok, auth} <- require_binding_value(auth_value),
         {:ok, session} <- require_optional_session(binding_mode, session_value) do
      binding_value =
        case binding_mode do
          :double -> auth <> session
          :single -> auth
        end

      {:ok, binding_value}
    end
  end

  defp fetch_socket_token(params, connect_info) do
    token =
      params["approov_token"] ||
        params["approov-token"] ||
        params["approovToken"] ||
        params["token"] ||
        header_value(connect_info, "approov-token")

    case token do
      value when is_binary(value) ->
        trimmed = String.trim(value)

        if trimmed == "" do
          {:error, :missing_approov_token}
        else
          {:ok, trimmed}
        end

      _ ->
        {:error, :missing_approov_token}
    end
  end

  defp require_binding_value(nil), do: {:error, :missing_binding_header}

  defp require_binding_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, :missing_binding_header}
    else
      {:ok, trimmed}
    end
  end

  defp require_binding_value(_value), do: {:error, :missing_binding_header}

  defp require_optional_session(:single, _value), do: {:ok, ""}
  defp require_optional_session(:double, value), do: require_binding_value(value)

  defp header_value(connect_info, header_name) do
    headers =
      case connect_info do
        %{x_headers: x_headers} -> x_headers
        _ -> []
      end

    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(key) == header_name do
        value
      end
    end)
  end

  defp param_value(params, keys) do
    Enum.find_value(keys, fn key ->
      value = params[key]

      if is_binary(value) do
        String.trim(value)
      end
    end)
  end
end

defmodule ApproovQuickstartWeb.ApproovUnauthorizedResponder do
  @moduledoc false

  import Plug.Conn

  @spec respond(Plug.Conn.t()) :: Plug.Conn.t()
  def respond(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{})
    |> halt()
  end
end

defmodule ApproovQuickstartWeb.ApproovTokenVerifier do
  @moduledoc false

  import Plug.Conn

  alias ApproovQuickstart.ApproovRequestVerifier
  alias ApproovQuickstartWeb.ApproovUnauthorizedResponder

  def init(opts), do: opts

  def call(conn, _opts) do
    case ApproovRequestVerifier.verify_http_request(conn) do
      {:ok, claims} ->
        put_private(conn, :approov_token_claims, claims)

      :skip ->
        conn

      {:error, reason} ->
        conn
        |> put_private(:approov_failure_reason, reason)
        |> ApproovUnauthorizedResponder.respond()
    end
  end
end

defmodule ApproovQuickstartWeb.Router do
  use ApproovQuickstartWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :approov_protected do
    plug ApproovQuickstartWeb.ApproovTokenVerifier
  end

  scope "/", ApproovQuickstartWeb do
    pipe_through :api

    get "/", ApproovController, :home
    get "/unprotected", ApproovController, :unprotected

    get "/approov-state", ApproovController, :approov_state
    post "/approov/enable", ApproovController, :enable_approov
    post "/approov/disable", ApproovController, :disable_approov

    post "/token-binding/enable", ApproovController, :enable_token_binding
    post "/token-binding/disable", ApproovController, :disable_token_binding
  end

  scope "/", ApproovQuickstartWeb do
    pipe_through [:api, :approov_protected]

    for %{method: method, path: path, action: action} <- ApproovQuickstart.ProtectedRoutes.all() do
      match method, path, ApproovController, action
    end
  end
end

defmodule ApproovQuickstartWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :approov_quickstart

  socket "/socket", ApproovQuickstartWeb.UserSocket,
    websocket: [
      connect_info: [:x_headers],
      serializer: [
        {ApproovQuickstartWeb.SocketSerializer.V1, "~> 1.0.0"},
        {ApproovQuickstartWeb.SocketSerializer.V2, "~> 2.0.0"}
      ]
    ],
    longpoll: false

  plug Plug.RequestId
  plug ApproovQuickstartWeb.RequestLogger

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug ApproovQuickstartWeb.Router
end

defmodule ApproovQuickstartWeb.ErrorJSON do
  def render(_template, _assigns) do
    %{}
  end
end

defmodule ApproovQuickstartWeb.ApproovController do
  use ApproovQuickstartWeb, :controller

  alias ApproovQuickstart.ApproovState

  def home(conn, _params) do
    json(conn, info_payload("Approov demo API is running on port #{http_port()}."))
  end

  def approov_state(conn, _params) do
    json(conn, ApproovState.state())
  end

  def enable_approov(conn, _params) do
    ApproovState.enable_approov()
    json(conn, ApproovState.state())
  end

  def disable_approov(conn, _params) do
    ApproovState.disable_approov()
    json(conn, ApproovState.state())
  end

  def enable_token_binding(conn, _params) do
    ApproovState.enable_token_binding()
    json(conn, ApproovState.state())
  end

  def disable_token_binding(conn, _params) do
    ApproovState.disable_token_binding()
    json(conn, ApproovState.state())
  end

  def unprotected(conn, _params) do
    json(conn, info_payload("Unprotected endpoint '/unprotected'; no Approov checks performed."))
  end

  def token_check(conn, _params) do
    json(conn, info_payload("Protected endpoint '/token-check'; Approov token verified."))
  end

  def token_binding(conn, _params) do
    authorization = get_req_header(conn, "authorization") |> List.first()

    response =
      info_payload("Protected endpoint '/token-binding'; Approov token binding enforced.")
      |> Map.put(:authorizationHeaderPresent, is_binary(authorization) and authorization != "")

    json(conn, response)
  end

  def token_double_binding(conn, _params) do
    authorization = get_req_header(conn, "authorization") |> List.first()
    session_id = get_req_header(conn, "sessionid") |> List.first()

    response =
      info_payload("Protected endpoint '/token-double-binding'; dual token binding enforced.")
      |> Map.put(:authorizationHeaderPresent, is_binary(authorization) and authorization != "")
      |> Map.put(:sessionIdHeaderPresent, is_binary(session_id) and session_id != "")

    json(conn, response)
  end

  defp info_payload(details) do
    ApproovState.state()
    |> Map.put(:details, details)
  end

  defp http_port do
    Application.get_env(:approov_quickstart, ApproovQuickstartWeb.Endpoint, [])
    |> Keyword.get(:http, [])
    |> Keyword.get(:port, 8080)
  end
end

defmodule ApproovQuickstartWeb.UserSocket do
  use Phoenix.Socket

  channel "echo:lobby", ApproovQuickstartWeb.EchoChannel

  alias ApproovQuickstart.ApproovRequestVerifier

  def connect(params, socket, connect_info) do
    case ApproovRequestVerifier.verify_socket_request(params, connect_info) do
      {:ok, claims} ->
        {:ok, assign(socket, :approov_token_claims, claims)}

      :skip ->
        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  def id(_socket), do: nil
end

defmodule ApproovQuickstartWeb.EchoChannel do
  use ApproovQuickstartWeb, :channel

  def join("echo:lobby", _payload, socket) do
    {:ok, socket}
  end

  def handle_in("echo", payload, socket) do
    push(socket, "echo", payload)
    {:noreply, socket}
  end
end

defmodule ApproovQuickstart.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: ApproovQuickstart.PubSub},
      ApproovQuickstart.ApproovState,
      ApproovQuickstartWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ApproovQuickstart.Supervisor)
  end

  def config_change(changed, _new, removed) do
    ApproovQuickstartWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
