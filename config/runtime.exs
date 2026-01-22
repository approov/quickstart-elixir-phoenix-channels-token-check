import Config

if config_env() == :prod do
  # production-specific config can go here
  :ok
end

port =
  System.get_env("HTTP_PORT", "8080")
  |> String.to_integer()

host = System.get_env("SERVER_HOSTNAME", "0.0.0.0")

secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise "SECRET_KEY_BASE is missing. Generate one with `mix phx.gen.secret`."

approov_secret_raw =
  System.get_env("APPROOV_BASE64URL_SECRET") ||
    raise "APPROOV_BASE64URL_SECRET is missing."

approov_secret =
  case Base.url_decode64(approov_secret_raw, padding: false) do
    {:ok, decoded} ->
      decoded

    :error ->
      case Base.url_decode64(approov_secret_raw, padding: true) do
        {:ok, decoded} -> decoded
        :error -> raise "APPROOV_BASE64URL_SECRET must be base64url-encoded"
      end
  end

config :approov_quickstart, :approov_secret, approov_secret

config :approov_quickstart, ApproovQuickstartWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: port],
  url: [host: host, port: port],
  secret_key_base: secret_key_base,
  server: true
