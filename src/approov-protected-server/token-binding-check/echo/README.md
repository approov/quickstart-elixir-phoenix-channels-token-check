# Approov Token Binding Integration Example

This Approov integration example is from where the code example for the [Approov token binding check quickstart](/docs/APPROOV_TOKEN_BINDING_QUICKSTART.md) is extracted, and you can use it as a playground to better understand how simple and easy it is to implement [Approov](https://approov.io) in an Elixir Phoenix Channels server.

## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Requirements](#requirements)
* [Try the Approov Integration Example](#try-it)
* [Running the Approov Protected Server](#running-the-approov-protected-server)
* [Testing with Postman](#testing-with-postman)
* [Testing with a Mobile App](#testing-with-a-mobile-app)


## Why?

To lock down your Phoenix Channels server to your mobile app. Please read the brief summary in the [README](/README.md#why) at the root of this repo or visit our [website](https://approov.io/product) for more details.

[TOC](#toc---table-of-contents)


## How it works?

The Elixir Phoenix Channels server is very simple and is defined in the project located at [src/approov-protected-server/token-binding-check/echo](/src/approov-protected-server/token-binding-check/echo).

The server only replies to Phoenix Channels websocket connections and to the `auth/register` and `auth/login` endpoints, but only when they present a valid Approov Token, just like the [Echo Chamber](https://github.com/approov/quickstart-flutter-graphql) mobile app example does, thus locking down the backend to only reply to requests of genuine instances of the mobile app.

### Approov Token Check

Take a look at the [Approov Token Plug](/src/approov-protected-server/token-binding-check/echo/lib/echo_web/plugs/approov_token_plug.ex) module to see how the Approov token check is invoked in the `call/2` function. To see the simple code for the Approov token check, you need to look into the `verify/1` function in the [Approov Token](/src/approov-protected-server/token-binding-check/echo/lib/approov_token.ex) module.

For more background on Approov, see the overview in the [README](/README.md#how-it-works) at the root of this repo.

### Approov Token Binding Check

The Approov token binding check can only be performed after a successful Approov token check, because it uses the `pay` key from the claims of the decoded Approov token payload. This is why you should always use the Approov plugs in the correct order:

```elixir
# src/approov-protected-server/token-binding-check/echo/lib/echo_web/router.ex

pipe_through :approov_token
pipe_through :approov_token_binding
```

Now, take a look at the [Approov Token Binding Plug](/src/approov-protected-server/token-binding-check/echo/lib/echo_web/plugs/approov_token_binding_plug.ex) module to see how the Approov token binding check is invoked in the `call/2` function. To see the simple code for the Approov token binding check, you need to look into the `verify_token_binding/1` function in the [Approov Token](/src/approov-protected-server/token-binding-check/echo/lib/approov_token.ex) module.

### User Authentication

This server also features a simple user authentication system for the [Echo Chamber](https://github.com/approov/quickstart-flutter-graphql) mobile app, via Phoenix tokens, that was designed to be completely anonymous, thus users are stored in the database as:

```elixir
iex> Echo.Repo.all! :users
[
  %{
    password_hash: "$2b$12$.8yuoqVi4p1244lboep61evCn1vmQmCgzCU36Fd952JPs9akHOJUG",
    uid: "7ACAE1DE920645200585DDE0D7467107FCC95E21464410399976E28956DBFFF3",
    username: "726C235B9B54334688B36248F45AC845D8B7A3D0F834C54A58DF1C5F45E65FF7"
  },
]
```

You can check by yourself how this is done at `src/approov-protected-server/token-binding-check/echo/lib/echo/user.ex`, and we hope that this approach gives you enough peace of mind while playing around with the [Echo Chamber](https://github.com/approov/quickstart-flutter-elixir-phoenix-channels/blob/master/src/echo-chamber-app) mobile app when its using our online server at `https://token.phoenix-channels.demo.approov.io`.

[TOC](#toc---table-of-contents)


## Requirements

To run this example you will need to have Elixir and Phoenix installed. If you don't have then please follow the official installation instructions from [here](https://hexdocs.pm/phoenix/installation.html#content) to download and install them.

Alternatively, you can use the provided docker stack via `src/approov-protected-server/token-binding-check/echo/docker-compose.yml`, and to use it you need to have [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/) installed in your system.

[TOC](#toc---table-of-contents)


## Running the Approov Protected Server

All the following shell commands will assume that you have your terminal open at the `src/approov-protected-server/token-binding-check/echo` folder.

From the root of this repo you can execute this bash command:

```bash
cd src/approov-protected-server/token-binding-check/echo
```

### The Dummy Secret

The valid Approov tokens in the Postman collection and cURL requests examples were signed with the dummy secret `h-CX0tOzdAAR9l15bWAqvq7w9olk66daIH-Xk-IAHhVVHszjDzeGobzNnqyRze3lw_WVyWrc2gZfh3XXfBOmww` that was generated with `openssl rand -base64 64 | tr -d '\n'; echo`, therefore not a production secret retrieved with the Approov CLI command `approov secret -get base64url`.

### Create the `.env` File

First, create the `.env` from `.env.example`:

```text
cp .env.example .env
```
Now, edit the `.env` file and adjust the `APPROOV_BASE64URL_SECRET` to the dummy secret value specified in the [previous section](#the-dummy-secret).

Next, populate the other secrets accordingly to the provided instructions in the comments of the `env` file.

### Run the Server with your Elixir Stack

> **IMPORTANT:** If you already have run the server with the Elixir docker stack we provide via the `docker-compose.yml` file then you need to delete the `_build` and `deps` folders.

First, don't forget to ensure that you are at the `src/approov-protected-server/token-binding-check/echo` folder.

Afterwards, you need to set the variables from the recently created `.env` file in your environment:

```bash
export $(grep -v '^#' .env | xargs -0)
```

Next, you need to install the dependencies with:

```bash
mix deps.get
```

Then you need to compile the dependencies with:

```bash
mix deps.compile
```

Now, you can run this server with an interactive `iex` shell:

```bash
iex -S mix phx.server
```

Or, run the server without an interactive `iex` shell:

```bash
mix phx.server
```

[TOC](#toc---table-of-contents)

### Run the Server with the Provided Elixir Docker Stack

> **IMPORTANT:** If you already have run the server with your local Elixir stack then before you try the docker stack you need to delete the `_build` and `deps` folders.

First, don't forget to ensure that you are in the correct folder, from the root of this repo you can execute this bash command:

```bash
cd src/approov-protected-server/token-binding-check/echo
```

Afterwards, build the docker image with:

```bash
sudo docker-compose build approov-token-binding-protected-dev
```

Next, you need to install the dependencies with:

```bash
sudo docker-compose run --rm approov-token-binding-protected-dev mix deps.get
```

Then you need to compile the dependencies with:

```bash
sudo docker-compose run --rm approov-token-binding-protected-dev mix deps.compile
```

Now, run the server with an interactive `iex` shell inside the docker container:

```bash
sudo docker-compose run --rm --service-ports approov-token-binding-protected-dev iex -S mix phx.server
```

Or, run the server without an interactive `iex` shell:

```bash
sudo docker-compose up
```

Finally, you can do a smoke test to check that it is up and running with:

```bash
curl -iX GET 'http://localhost:8002'
```

The response will be:

```text
HTTP/1.1 401 Unauthorized
cache-control: max-age=0, private, must-revalidate
content-length: 2
content-type: application/json; charset=utf-8
date: Thu, 31 Mar 2022 22:09:56 GMT
server: Cowboy
x-request-id: FuGWqmhGv58mr1IAAAZC

{}
```

The reason you got a `401` is because the Approoov token isn't provided in the headers of the request.

Now that you know the server is working you can use Postman or the companion mobile app to test the Phoenix Channels websocket. Check the next sections to see how to.

[TOC](#toc---table-of-contents)


## Testing With Postman

You will use cURL to create and login an user and then use Postman to connect to the Phoenix channels websocket and to send messages to it.

### User Registration and Login via cURL

To make the cURL requests it's necessary an Approov token. In the `.env` file you have configured this server with a dummy secret for Approov, therefore the below Approov tokens were signed with it.

First, let's register an user with:

```bash
curl --request POST 'http://localhost:8002/auth/register' \
  --header "X-Approov-Token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ.c8I4KNndbThAQ7zlgX4_QDtcxCrD9cff1elaCJe9p9U" \
  --data username=test@mail.com \
  --data password=your-super-secret-long-strong-pass-here
```

The request should be accepted. For example:

```json
{"id":"B4C20F1BBC39F610CF4608F83A06DEA85884D77C854BBB3D10EF239641B9B861"}
```

Next, let's login the user with the Approov protected endpoint:

```bash
curl --request POST 'http://localhost:8002/auth/login' \
  --header "X-Approov-Token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ.c8I4KNndbThAQ7zlgX4_QDtcxCrD9cff1elaCJe9p9U" \
  --data username=test@mail.com \
  --data password=your-super-secret-long-strong-pass-here
```

The request should be accepted. For example:

```json
{"token":"Bearer ___YOUR_AUTHORIZATION_TOKEN___"}
```

Finally, you have the Bearer Authorization token that is required to represent a logged-in user when using Postman to establish a websocket connection and send messages to the backend. Keep the Authorization token at hand, because you will need to use it in Postman.

### Setup Postman

First, you need to bear in mind that support for websockets in Postman is only supported in workspaces, that require you to be a logged-in user.

Next, create a Postman environment and add to it the variable `AUTHORIZATION_TOKEN` with the value being the bearer token you got from the login request `Bearer ___YOUR_AUTHORIZATION_TOKEN___`. **No need to copy the word Bearer**.

A Postman collection cannot be provided (at the time of writing), because Postman doesn't have support to export a websocket collection, like it has for REST APIs. So, start by creating one, and give it a name, for example `Approoov - Phoenix Channels`, and afterwards select the environment you have created above for this collection.

Finally, you are now ready to start creating your websocket request to connect to the `echo:chamber` Phoenix channel for  sending messages to it.

### Phoenix Channel Websosocket - Valid Requests

In this section you will use Postman to connect to the Phoenix Channel and for sending messages to it.

#### Creating Local Approov Tokens

To be able to test your Phoenix Channels running in localhost, without having the Approov CLI to generate Approov tokens, you can create dummy ones with the included `bin/token.exs` Elixir script, that requires you to be running at least Elixir `1.12`.

If you are not running a shell inside the provided docker stack, then you need to source into your environment the `.env` file, to allow for the script to fetch the `APPROOV_BASE64URL_SECRET`.

To create a token just run from `./src/approov-protected-server/token-binding-check/echo`:

```bash
source ./.env && elixir bin/token.exs
```

or using the docker stack:

```bash
sudo docker-compose run --rm approov-token-binding-protected-dev elixir bin/token.exs
```

You should be asked for the Authorization token. For example:

```text
You need to use the authorization token returned by the Login request.

Authorization Token:
```

After you provide the Authorization token the final output should look like this:

```text
You need to use the authorization token returned by the Login request.

Authorization Token: QTEyOEdDTQ.gnTAOyz7-kUjq3R8-pgpX3fslqTJCuNnwciPlYO5rdxfi5geqTpw9kTdnik.L0yfobZg66O0wP08.B0rI-5G4Mi-gMqiSct7u6EEXv7rD7XNb0nq-HCzZ3PQ6VqMzLiB-4TJD42PX7_1wpoa75YqHWIad-lB-v9riakvdL-XPS4CHULVsJVIWi-aqFvOwYbpo2hL9N3uGwanqQw.5mBL1s9RbECILEPK-Xr8AA

Approov Token Binding: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjQ1MTYyMzkwMjIsInBheSI6IjMxZDhQcDJBekZkN3RkM2o0ekRDSHRNUWJmbERSU0g2NjRzMThvR1RkWUU9In0.kq-exRgbaSfx6_dHA_T8rHTsaqm1icHl1XSua-yli5w
```

Now, grab the Approov Token Binding and use it in the Postman collection to establish a connection with the Phoenix Channel and to send messages to it. You will learn how in the next section.

#### Connect to a Phoenix Channel

First, you need to set the `APPROOV_TOKEN_BINDING` environment variable in Postman, with the value of the Approov token binding you got when you ran `elixir bin/token.exs` on the previous step.

Now, you need to create a websocket request in your newly created collection, where you will use this URL and parameters:

```text
ws://localhost:8002/socket/websocket?Authorization=Bearer {{AUTHORIZATION_TOKEN}}&X-Approov-Token={{APPROOV_TOKEN_BINDING}}
```

Next, to connect to the Phoenix channel just click the `Connect` button on the right side of the request URL.

The request to connect should have been accepted, and a green tick should be seen in the message tab entry for the request, unless you forgot to update the Authorization token, or messed with the Approov token.

#### Joining a Phoenix Channel Topic

First, you need to create the joining event message to send to the Phoenix channel, for example:

```json
{
    "event": "phx_join",
    "topic": "echo:chamber",
    "ref": "approov-token-binding",
    "payload": {
        "X-Approov-Token": "{{APPROOV_TOKEN_BINDING}}",
        "Authorization": "Bearer {{AUTHORIZATION_TOKEN}}"
    }
}
```

Now, you can save it and give it a name, like `phx_join`. Afterwards, you can click in the `Send` button, and you should see in the `Messages` tab the successful connection, followed by the message you sent and by the reply from the Phoenix Channel.

Example of a reply received from the Phoenix Channel:

```json
{
    "event": "phx_reply",
    "payload": {
        "response": {},
        "status": "ok"
    },
    "ref": "approov-token-binding",
    "topic": "echo:chamber"
}
```

You are now subscribed to the Phoenix channel topic `echo:chamber`, therefore you can start sending as many messages to it as you want.

#### Sending Messages to the Phoenix Channel Topic

First, to send your message you need to compose another message, for example:

```json
{
    "event": "echo_it",
    "topic": "echo:chamber",
    "ref": "approov-token-binding",
    "payload": {
        "message": "Approov Protected Phoenix Channel",
        "X-Approov-Token": "{{APPROOV_TOKEN_BINDING}}",
        "Authorization": "Bearer {{AUTHORIZATION_TOKEN}}"
    }
}
```

Now, you can save the message with the name `echo_it` and then click in the `Send` button, and finally you should see the event being sent in the `Messages` tab, followed by the reply from the Phoenix Channel.

Example of a reply received from the Phoenix Channel:

```json
{
    "event": "echo:chamber",
    "payload": {
        "message": "Approov Protected Phoenix Channel, Approov Protected Phoenix Channel, Approov Protected Phoenix Channel..."
    },
    "ref": null,
    "topic": "echo:chamber"
}
```

As you can see the message you sent was echoed three times in the reply. Try it now with your own message.

To customize the message you need to find the key `payload > message` on the JSON that is sent to the Phoenix Channel and replace the value `___YOUR_MESSAGE_HERE___` with whatever you want:

```json
{
    "payload": {
        "message": "___YOUR_MESSAGE_HERE___",
    }
}
```

### Phoenix Channel Websosocket - Invalid Requests

Until now you have connected to the Phoenix Channel websocket with valid Approov tokens, but I now challenge you to try out other requests for failure scenarios:

* Expired Approov token, for example `eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjE1NTUwODMzNDkuMzc3NzYyM30.XzZs_ItunAmisfTAuLLHqTytNnQqnwqh0Koh3PPKAoM`.
* Invalid signature for the Approov token, for example `eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJleHAiOjQ3MDg2ODMyMDUuODkxOTEyfQ.c8I4KNndbThAQ7zlgX4_QDtcxCrD9cff1elaCJe9p9A`
* Valid Approov Token with invalid token biding, for example `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjQ1MTYyMzkwMjIsInBheSI6Im1YeXJ2dlRXM0RWTEFETDU3WHl5clMvODNpMEg3ZnJ6aWptSVgyeDhVenc9In0.4wyWLEBvdxGya6Tu8Kq0CUBYpGWQ4F73LXRlS4CFwkU`
* Malformed token, for example `abc.cde`
* Not sending the Approov token
* Sending the Approov token as an empty string

To test such scenarios just edit/duplicate the websocket request and replace the Approov token with one of the dummy tokens provided above.

While doing such requests you will notice that you will never be able to connect to the Phoenix channel, and this is because the Approov token isn't a valid one, the token binding doesn't match the Authorization token, or the Approov token is missing in the request.

Being able to test the Phoenix Channels websocket from Postman isn't the only option, as per the next section.

## Testing with a Mobile App

To test the echo chamber functionality, that uses Phoenix channels via websockets, you need to follow [this instructions](https://github.com/approov/quickstart-flutter-elixir-phoenix-channels/blob/master/ECHO-CHAMBER-EXAMPLE.md#try-the-echo-chamber-app-without-approov) to run the Echo Chamber mobile app example for this backend.


[TOC](#toc---table-of-contents)


## Docker Stack Cleanup

If you were using the included docker stack, then after finish testing you may want to completely remove the docker stack. Just execute the two below commands:

```bash
sudo docker-compose down
docker image ls | grep 'approov/quickstart-elixir-phoenix-channels' | awk '{print $3}' | xargs sudo docker image rm
```

[TOC](#toc---table-of-contents)
