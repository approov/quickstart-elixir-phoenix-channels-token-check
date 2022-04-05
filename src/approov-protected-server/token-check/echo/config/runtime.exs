import Config

################################################################################
# LOAD FROM ENV
################################################################################

load_from_env = fn (var, default_value)
  when is_binary(var) ->
    case System.get_env(var, default_value) do
      value when is_binary(value) and byte_size(value) >= 1 ->
        value

      _ ->
        raise "CONFIG ERROR: Environment variable #{var} is missing"
    end
  end

################################################################################
# END LOAD FROM ENV
################################################################################

url_public_scheme = load_from_env.("URL_PUBLIC_SCHEME", "https")
url_public_host = load_from_env.("URL_PUBLIC_HOST", nil)
url_public_port = load_from_env.("URL_PUBLIC_PORT", "443")
url_public = "#{url_public_scheme}://#{url_public_host}"

config :echo, ApproovToken,
  # secret_key: Base.decode64!(load_from_env.("APPROOV_BASE64URL_SECRET", nil), ignore: :whitespace)
  secret_key: load_from_env.("APPROOV_BASE64URL_SECRET", nil)

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
config :echo, EchoWeb.Endpoint,
  secret_key_base: load_from_env.("SECRET_KEY_BASE", nil),
  encryption_secret: load_from_env.("ENCRYPTION_SECRET", nil),
  server: true,
  http: [
    # Like the one used inside a docker container and/or behind a proxy
    port: load_from_env.("HTTP_INTERNAL_PORT", nil),
    transport_options: [
      socket_opts: [:inet6],
    ],
  ],
  url: [
    scheme: url_public_scheme,
    host: url_public_host,
    port: url_public_port
  ],
  # check_origin: true,
  check_origin: ["#{url_public}:#{url_public_port}"],
  live_view: [signing_salt: load_from_env.("LIVE_VIEW_SIGNING_SALT", nil)],
  live_view_dashboard_user: load_from_env.("LIVE_VIEW_DASHBOARD_USER", nil),
  live_view_dashboard_password: load_from_env.("LIVE_VIEW_DASHBOARD_PASSWORD", nil)


# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
