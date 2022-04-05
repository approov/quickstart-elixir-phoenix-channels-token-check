defmodule EchoWeb.Router do
  use EchoWeb, :router

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

  pipeline :approov_token do
    # Ideally you will not want to add any other Plug before the Approov Token
    # check to protect your server from wasting resources in processing requests
    # not having a valid Approov token. This increases availability for your
    # users during peak time or in the event of a DoS attack(We all know the
    # BEAM design allows to cope very well with this scenarios, but best to play
    # in the safe side).
    plug EchoWeb.ApproovTokenPlug
  end

  # To use in any endpoint that is not the /auth/*
  pipeline :approov_token_binding do
    plug EchoWeb.ApproovTokenBindingPlug
  end

  scope "/" do
    pipe_through :api

    # Any endpoint declared below this line will be checked for a valid and not
    # expired Approov token
    pipe_through :approov_token

    get "/", EchoWeb.EchoController, :show
    post "/auth/register", EchoWeb.AuthController, :register
    post "/auth/login", EchoWeb.AuthController, :login

    # Any endpoint declared after this line will be protected with the extra
    # Approov Token Binding check
    pipe_through :approov_token_binding

  end

  scope "/dashboard" do
    pipe_through [:browser, :live_view_dashboard_auth]
    live_dashboard "/"
  end

end
