import Config

config :approov_quickstart,
  ecto_repos: []

config :approov_quickstart, ApproovQuickstartWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [formats: [json: ApproovQuickstartWeb.ErrorJSON], layout: false],
  pubsub_server: ApproovQuickstart.PubSub,
  live_view: [signing_salt: "approov_salt"]

config :phoenix, :json_library, Jason

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, level: :info
