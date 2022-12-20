# Approov QuickStart - Elixir Phoenix Channels Token Check

[Approov](https://approov.io) is an API security solution used to verify that requests received by your backend services originate from trusted versions of your mobile apps.

This repo implements the Approov server-side request verification code in [Elixir](https://elixir-lang.org/), which performs the verification check before allowing valid traffic to be processed by the API endpoint.

This is an Approov integration quickstart example for the Elixir Phoenix framework, that protects [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html) with an Approov token check. If you are looking for another Elixir integration you can check our list of [quickstarts](https://approov.io/docs/latest/approov-integration-examples/backend-api/), and if you don't find what you are looking for, then please let us know [here](https://approov.io/contact).


## Approov Integration Quickstart

The quickstart was tested with the following Operating Systems:

* Ubuntu 20.04
* MacOS Big Sur
* Windows 10 WSL2 - Ubuntu 20.04

First, setup the [Approov CLI](https://approov.io/docs/latest/approov-installation/index.html#initializing-the-approov-cli).

Now, register the API domain for which Approov will issues tokens:

```bash
approov api -add api.example.com
```

> **NOTE:** By default a symmetric key (HS256) is used to sign the Approov token on a valid attestation of the mobile app for each API domain it's added with the Approov CLI, so that all APIs will share the same secret and the backend needs to take care to keep this secret secure.
>
> A more secure alternative is to use asymmetric keys (RS256 or others) that allows for a different keyset to be used on each API domain and for the Approov token to be verified with a public key that can only verify, but not sign, Approov tokens.
>
> To implement the asymmetric key you need to change from using the symmetric HS256 algorithm to an asymmetric algorithm, for example RS256, that requires you to first add a new key, and then specify it when adding each API domain. Please visit Managing Key Sets on the Approov documentation for more details.

Next, enable your Approov `admin` role with:

```bash
eval `approov role admin`
````

For the Windows powershell:

```bash
set APPROOV_ROLE=admin:___YOUR_APPROOV_ACCOUNT_NAME_HERE___
````

Now, retrieve the [Approov secret](https://approov.io/docs/latest/approov-usage-documentation/#account-secret-key-export):

```bash
approov secret -get base64Url
```

Next, export the Approov secret into the environment:

```env
export APPROOV_BASE64URL_SECRET=approov_base64url_secret_here
```

Now, fetch the Approov secret in the `config/runtime.exs` file:

```elixir
import Config

approov_secret =
  System.get_env("APPROOV_BASE64URL_SECRET") ||
    raise "Environment variable APPROOV_BASE64URL_SECRET is missing."

config :YOUR_APP, ApproovToken,
  secret_key: approov_secret
```

Next, add the [JWT dependency](https://github.com/joken-elixir/joken) to your `mix.exs` file:

```elixir
{:joken, "~> 2.4"},
# Recommended JSON library
{:jason, "~> 1.2"}
```

Fetch the new dependency:

```bash
mix deps.get
```

Add the `ApproovToken` Module to your project:

```elixir
defmodule ApproovToken do

  use Joken.Config

  @impl Joken.Config
  def token_config, do: default_claims(skip: [:aud, :iat, :iss, :jti, :nbf])

  # Verifies the token from an HTTP request or from a Websockets connection/event
  def verify_token(params) do
    with {:ok, approov_token} <- _get_approov_token(params),
         {:ok, approov_token_claims} <- _decode_and_verify(approov_token) do

      {:ok, approov_token_claims}
    else
      {:error, reason} ->
        # You may want to add logging here
        {:error, reason}
    end
  end


  ########################
  # APPROOV TOKEN FETCH
  ########################

  # For when the Approov token is the header of a regular HTTP Request
  defp _get_approov_token(%Plug.Conn{} = conn) do
    case Plug.Conn.get_req_header(conn, "x-approov-token") do
      [] ->
        _get_approov_token(conn.params)

      [approov_token | _] ->
        {:ok, approov_token}
    end
  end

  # Fetch for a Phoenix Channel event, where the token is provided in the event payload.
  defp _get_approov_token(%{"x-approov-token" => approov_token}), do: {:ok, approov_token}
  defp _get_approov_token(%{"X-Approov-Token" => approov_token}), do: {:ok, approov_token}

  # Catch failure to fetch the Approov token from the WebSocket upgrade request
  # or from the Phoenix Channel event.
  defp _get_approov_token(_params) do
    {:error, :missing_approov_token}
  end


  ########################
  # APPROOV TOKEN CHECK
  ########################

  defp _decode_and_verify(approov_token) do
    secret = Application.fetch_env!(:echo, ApproovToken)[:secret_key]

    # call `verify_and_validate/2` injected by `use Joken.Config`
    case verify_and_validate(approov_token, Joken.Signer.create("HS256", secret)) do
      {:ok, %{"exp" => _expiration}} = result ->
        result

      # The library only checks the `exp` when present, and verifies successfully
      # without it, and doesn't have an option to enforce it.
      {:ok, _claims} ->
        {:error, :missing_expiration_time}

      result ->
        result
    end
  end

end
```

### Approov Token Plug to Protect HTTP Requests

First, add this simple Approov Token plug to your project. For example at `lib/your_app_web/plugs/approov_token_plug.ex`:

```elixir
defmodule YourAppWeb.ApproovTokenPlug do

  def init(opts), do: opts

  def call(conn, _opts) do
    case ApproovToken.verify_token(conn) do
      {:ok, approov_token_claims} ->
        conn
        |> Plug.Conn.put_private(:echo_approov_token_claims, approov_token_claims)

      {:error, _reason} ->
        conn
        |> _halt_connection()
    end
  end

  # When the Approov token validation fails we return a `401` with an empty body,
  # because we don't want to give clues to an attacker about the reason the
  # request failed, and you can go even further by returning a `400`. Feel free
  # to modify as you see fits best your use case.
  defp _halt_connection(conn) do
    conn
    |> Plug.Conn.put_status(401)
    |> Phoenix.Controller.json(%{})
    |> Plug.Conn.halt()
  end

end
```

Next, create and use the pipeline for the Approov token check at `lib/your_app_web/router.ex`:

```elixir
# @IMPORTANT:
#
# Ideally any other type of Authentication pipeline should only come after the
# Approov token. For example, doesn't make sense to check the user credentials
# before you check if you can trust in the request with the Approov Token plug.
#
# Also, you may not want to add any other Plug before the Approov Token plug to
# avoid your server from wasting resources in processing requests not having
# a valid Approov token.
#
# Following this advice's increases availability for your users during peak
# time or in the event of a DoS attack, because your server is refusing the
# connection without further processing other paths in your code. We all know
# that the BEAM design allows to cope and be more resilient to this scenarios,
# but doesn't hurt to play on the safe side.

pipeline :approov_token do
  plug YourAppWeb.ApproovTokenPlug
end

scope "/" do

  # The API pipeline is an exception to the above advice because it's setting
  # the response content type to JSON.
  pipe_through :api
  pipe_through :approov_token

  # Your endpoints go after this line, for example:
  get "/", YourAppWeb, YourAppWeb.ApiController, :index
  post "/auth/register", YourAppWeb.AuthController, :register
  post "/auth/login", YourAppWeb.AuthController, :login
end
```

### Approov Token Check to Protect Websockets Requests

First, open the file where you establish the websocket connection. For example, `lib/your_app_web/user_socket.ex`, and add to it this code:

```elixir
defp _authorize(socket, params, connect_info) do

  headers = Map.merge(params, connect_info)

  # Always perform the Approov token check before the User Authentication.
  with {:ok, _approov_token_claims} <- ApproovToken.verify_token(headers),
       {:ok, current_user} <- Echo.User.authorize(params: params) do

    socket = Phoenix.Socket.assign(socket, context: %{current_user: current_user})

    {:ok, socket}
  else
    {:error, _reason} ->
      :error
  end
end
```

The above `_authorize/2` function needs to be the first one to be invoked in your `connect/3` function pipeline. For example:

```elixir
def connect(params, socket, _connect_info) do
  socket
  |> _authorize(params)
  |> _other_stuff()
end
```

### Approov Token Check to Protect Phoenix Channels Incoming Events

First, open each of the Phoenix Channel modules on your project and add the following code:

```elixir
defp _authorized(action, payload, socket) do
  # Always perform the Approov token check before doing the User Authorization.
  with {:ok, _approov_token_claims} <- ApproovToken.verify_token(payload),
       # Dummy code to exemplify user authorization being used
       {:ok, current_user} <- YourApp.User.authorize(params: payload),
    {:ok, socket}
  else
    {:error, _reason} ->
      # You may want to add some logging here
      :error
  end
end
```

Next, you need to wrap all your logic in a call to `_authorized/3` for each `join/3` function and in each `handle_in/3` function on the same modules. For example:

```elixir
def join("channel:event", payload, socket) do
  case _authorized(:join, payload, socket) do
    {:ok, socket} ->

      # YOUR LOGIC GOES HERE...

      {:ok, socket}

    _ ->
      {:error, %{reason: "Whoops, something went wrong!"}}
  end
end

def handle_in("event:action", payload, socket) do
  case _authorized(:action_name, payload, socket) do
    {:ok, socket} ->

      # YOUR LOGIC GOES HERE...

      {:noreply, socket}

    _ ->
      {:noreply, socket}
  end
end
```

Not enough details in the bare bones quickstart? No worries, check the [detailed quickstarts](QUICKSTARTS.md) that contain a more comprehensive set of instructions, including how to test the Approov integration.


## More Information

* [Approov Overview](OVERVIEW.md)
* [Detailed Quickstarts](QUICKSTARTS.md)
* [Step by Step Examples](EXAMPLES.md)
* [Testing](TESTING.md)

### System Clock

In order to correctly check for the expiration times of the Approov tokens is very important that the backend server is synchronizing automatically the system clock over the network with an authoritative time source. In Linux this is usually done with a NTP server.


## Issues

If you find any issue while following our instructions then just report it [here](https://github.com/approov/quickstart-swift-vapor-token-check/issues), with the steps to reproduce it, and we will sort it out and/or guide you to the correct path.


## Useful Links

If you wish to explore the Approov solution in more depth, then why not try one of the following links as a jumping off point:

* [Approov Free Trial](https://approov.io/signup)(no credit card needed)
* [Approov Get Started](https://approov.io/product/demo)
* [Approov QuickStarts](https://approov.io/docs/latest/approov-integration-examples/)
* [Approov Docs](https://approov.io/docs)
* [Approov Blog](https://approov.io/blog/)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.io/contact)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/contact)
