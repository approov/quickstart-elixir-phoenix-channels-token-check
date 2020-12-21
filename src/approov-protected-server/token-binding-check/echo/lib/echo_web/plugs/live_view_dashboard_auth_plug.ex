defmodule EchoWeb.LiveViewDashboardAuthPlug do

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.BasicAuth.basic_auth(
      conn,
      username: Utils.fetch_from_env!(:echo, EchoWeb.Endpoint, :live_view_dashboard_user, 8, :string),
      password: Utils.fetch_from_env!(:echo, EchoWeb.Endpoint, :live_view_dashboard_password, 12, :string)
    )
  end
end
