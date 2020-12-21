defmodule Echo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do

    # @TODO Create tables owned only by the process using them. so that they
    #       don't need to be public. I think we need to create a GenServer to
    #       access it, but not sure... need to investigate further.
    :ets.new(:users, [:set, :named_table, :public])

    children = [
      # Start the Telemetry supervisor
      EchoWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Echo.PubSub},
      # Start the Endpoint (http/https)
      EchoWeb.Endpoint
      # Start a worker by calling: Echo.Worker.start_link(arg)
      # {Echo.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Echo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EchoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
