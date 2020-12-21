defmodule EchoWeb.Router do
  use EchoWeb, :router

  import Plug.BasicAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :live_view_dashboard_auth do
    plug EchoWeb.LiveViewDashboardAuthPlug
  end

  scope "/" do
    pipe_through :api

    post "/auth/register", EchoWeb.AuthController, :register
    post "/auth/login", EchoWeb.AuthController, :login
  end

  scope "/dashboard" do
    pipe_through [:browser, :live_view_dashboard_auth]
    live_dashboard "/"
  end

end
