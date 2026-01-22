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
  @digest_header "content-digest"

  @impl Joken.Config
  def token_config, do: default_claims(skip: [:aud, :iat, :iss, :jti, :nbf])

  def verify_token(%Plug.Conn{} = conn) do
    with {:ok, token} <- fetch_approov_token(conn),
         {:ok, claims} <- verify_and_decode(token) do
      {:ok, claims}
    else
      {:error, reason} ->
        Logger.info(%{approov_token_error: reason})
        {:error, reason}
    end
  end

  def verify_binding(%Plug.Conn{} = conn, %{} = claims, binding_mode) do
    with {:ok, binding_value} <- extract_binding_value(conn, binding_mode),
         :ok <- validate_binding(binding_value, claims) do
      :ok
    else
      {:error, reason} ->
        Logger.info(%{approov_binding_error: reason})
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
    Application.fetch_env!(:approov_quickstart, :approov_secret)
  end

  def extract_binding_value(conn, :single) do
    case Plug.Conn.get_req_header(conn, @auth_header) do
      [value | _] when is_binary(value) and byte_size(value) > 0 ->
        {:ok, String.trim(value)}

      _ ->
        {:error, :missing_binding_header}
    end
  end

  def extract_binding_value(conn, :double) do
    auth = Plug.Conn.get_req_header(conn, @auth_header) |> List.first()
    digest = Plug.Conn.get_req_header(conn, @digest_header) |> List.first()

    if is_binary(auth) and is_binary(digest) and byte_size(String.trim(auth)) > 0 and
         byte_size(String.trim(digest)) > 0 do
      {:ok, String.trim(auth) <> String.trim(digest)}
    else
      {:error, :missing_binding_headers}
    end
  end

  def extract_binding_value(_conn, _binding_mode), do: {:error, :unsupported_binding_mode}

  def validate_binding(binding_value, %{"pay" => expected}) when is_binary(expected) do
    computed = hash_base64(binding_value)

    if expected == computed do
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
      use Phoenix.Controller, namespace: ApproovQuickstartWeb, formats: [:json]
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

defmodule ApproovQuickstartWeb.ApproovTokenVerifier do
  @moduledoc false

  import Plug.Conn

  alias ApproovQuickstart.ApproovState
  alias ApproovQuickstart.ApproovToken
  alias ApproovQuickstart.ProtectedRoutes

  def init(opts), do: opts

  def call(conn, _opts) do
    if ApproovState.approov_enabled?() do
      with {:ok, claims} <- ApproovToken.verify_token(conn),
           :ok <- verify_binding_if_needed(conn, claims) do
        put_private(conn, :approov_token_claims, claims)
      else
        {:error, _reason} -> unauthorized(conn)
      end
    else
      conn
    end
  end

  defp verify_binding_if_needed(conn, claims) do
    case ProtectedRoutes.binding_for(conn.request_path) do
      :none ->
        :ok

      binding_mode ->
        if ApproovState.token_binding_enabled?() do
          ApproovToken.verify_binding(conn, claims, binding_mode)
        else
          :ok
        end
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{})
    |> halt()
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
    websocket: true,
    longpoll: false

  plug Plug.RequestId
  plug Plug.Logger

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
    content_digest = get_req_header(conn, "content-digest") |> List.first()

    response =
      info_payload("Protected endpoint '/token-double-binding'; dual token binding enforced.")
      |> Map.put(:authorizationHeaderPresent, is_binary(authorization) and authorization != "")
      |> Map.put(:contentDigestHeaderPresent, is_binary(content_digest) and content_digest != "")

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

  def connect(_params, socket, _connect_info) do
    {:ok, socket}
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
