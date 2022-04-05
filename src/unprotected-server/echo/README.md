# Unprotected Server Example

The unprotected example is the base reference to build the [Approov protected servers](/src/approov-protected-server/). This a very basic Elixir Phoenix Channels API server.


## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Requirements](#requirements)
* [Running the Server](#running-the-server)
* [Testing with Postman](#testing-with-postman)
* [Testing with a Mobile App](#testing-with-a-mobile-app)

## Why?

To be the starting building block for the [Approov protected servers](/src/approov-protected-server/echo), that will show you how to lock down your API server to your mobile app. Please read the brief summary in the [README](/README.md#why) at the root of this repo or visit our [website](https://approov.io/product) for more details.

[TOC](#toc---table-of-contents)


## How it works?

The Elixir Phoenix Channels API server is very simple and is defined in the project located at [src/unprotected-server/echo](/src/unprotected-server/echo).

The server only replies to Phoenix Channels connections and to the `auth/register` and `auth/login` endpoints.

### User Authentication

This server also features a simple user authentication system for the [Echo Chamber mobile app](https://github.com/approov/quickstart-flutter-graphql), via Phoenix tokens, that was designed to be completely anonymous, thus users are stored in the database as:

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

You can check by yourself how this is done at `src/approov-protected-server/token-check/echo/lib/echo/user.ex`, and we hope that this approach gives you enough peace of mind when playing around with the [Echo Chamber mobile app](https://github.com/approov/quickstart-flutter-elixir-phoenix-channels/blob/master/src/echo-chamber-app) that may use this server at `https://token.phoenix-channels.demo.approov.io`.

[TOC](#toc---table-of-contents)


## Requirements

To run this example you will need to have Elixir and Phoenix installed. If you don't have then please follow the official installation instructions from [here](https://hexdocs.pm/phoenix/installation.html#content) to download and install them.

Alternatively, you can use the provided docker stack via `src/approov-protected-server/token-check/echo/docker-compose.yml`, and to use it you need to have [Docker](https://docs.docker.com/install/) and [Docker Compose](https://docs.docker.com/compose/install/) installed in your system.

[TOC](#toc---table-of-contents)


## Running the Server

All the following shell commands will assume that you have your terminal open at the `src/unprotected-server/echo` folder.

### Create the `.env` File

First, create the `.env` from `.env.example`:

```text
cp .env.example .env
```

Now, edit the `.env` file and adjust the secrets accordingly to the provided instructions in the comments.

### Run the Server with your Elixir Stack

> **IMPORTANT:** If you already have run the server with the Elixir docker stack we provide via the `docker-compose.yml` file then you need to delete the `_build` and `deps` folders.

First, don't forget to ensure that you are at the `src/unprotected-server/echo` folder.

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

First, don't forget to ensure that you are at the `src/unprotected-server/echo` folder.

Afterwards, build the docker image with:

```bash
sudo docker-compose build unprotected-dev
```

Next, you need to install the dependencies with:

```bash
sudo docker-compose run --rm unprotected-dev mix deps.get
```

Then you need to compile the dependencies with:

```bash
sudo docker-compose run --rm unprotected-dev mix deps.compile
```

Now, run the server with an interactive `iex` shell inside the docker container:

```bash
sudo docker-compose run --rm --service-ports unprotected-dev iex -S mix phx.server
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
HTTP/1.1 200 OK
cache-control: max-age=0, private, must-revalidate
content-length: 27
content-type: application/json; charset=utf-8
date: Wed, 30 Mar 2022 12:15:46 GMT
server: Cowboy
x-request-id: FuEnqVsP_m-J4lwAAATh

{"message":"Hello, World!"}
```

[TOC](#toc---table-of-contents)


## Testing With Postman

You will use cURL to create and login an user and then use Postman to connect to the Phoenix channels websocket and to send messages to it.

### User Registration and Login via cURL

First, let's register an user with:

```bash
curl --request POST 'http://localhost:8002/auth/register' \
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
  --data username=test@mail.com \
  --data password=your-super-secret-long-strong-pass-here
```

The request should be accepted. For example:

```json
{"token":"Bearer ___YOUR_AUTHORIZATION_TOKEN___"}
```

Finally, you have the Bearer Authorization token that is required to represent a logged-in user when using Postman to establish a websocket connection and send messages to the backend. Keep the Authorization token at hand, because you will need to use it in Postman.

### Setup Postman

First, you need to add [this collection](https://raw.githubusercontent.com/approov/postman-collections/master/quickstarts/echo/echo-websockets.postman_collection.json) to your Postman workspace. Bear in mind that support for websockets in Postman is only supported in workspaces, that require you to be a logged-in user.

Now, you need to select the *Echo It* websocket request on the collection *Approov - Phoenix Channels - Echo*.

Next, create a Postman environment and add to it the variable `AUTHORIZATION_TOKEN` with the value being the bearer token you got from the login request `Bearer ___YOUR_AUTHORIZATION_TOKEN___`. **No need to copy the word Bearer**.

Finally, you are ready to connect to the `echo:chamber` Phoenix channel for sending messages to it.

### Phoenix Channel Websosocket Requests

In this section you will use Postman to connect to the Phoenix Channel and for sending messages to it.

#### Connect to a Phoenix Channel

To connect to the Phoenix channel just select the message *phx_join* and click in the *Send* button, and you should see in the *Messages* tab the successful connection, followed by the message you sent and by the reply from the Phoenix Channel.

Example of an event sent to the Phoenix Channel:

```json
{
    "event": "phx_join",
    "topic": "echo:chamber",
    "ref": "approov",
    "payload": {
        "Authorization": "Bearer {{AUTHORIZATION_TOKEN}}"
    }
}
```

Example of a reply received from the Phoenix Channel:

```json
{
    "event": "phx_reply",
    "payload": {
        "response": {},
        "status": "ok"
    },
    "ref": "approov",
    "topic": "echo:chamber"
}
```

You are now connected to the Phoenix channel, therefore you can start sending as many messages to it as you want.

#### Sending Messages to the Phoenix Channel

To send your message you just need to select from the *Saved messages* tab the message *echo_it* and click in the *Send* button, and you should see in the *Messages* tab the event being sent, followed by the reply from the Phoenix Channel.

Example of an event sent to the Phoenix Channel:

```json
{
    "event": "echo_it",
    "topic": "echo:chamber",
    "ref": "approov",
    "payload": {
        "message": "Approov unprotected Phoenix Channel",
        "Authorization": "Bearer {{AUTHORIZATION_TOKEN}}"
    }
}
```

Example of a reply received from the Phoenix Channel:

```json
{
    "event": "echo:chamber",
    "payload": {
        "message": "Approov unprotected Phoenix Channel, Approov unprotected Phoenix Channel, Approov unprotected Phoenix Channel..."
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

When you finish testing you may want to completely remove the docker stack. Just execute the two below commands:

```bash
sudo docker-compose down
docker image ls | grep 'approov/quickstart-elixir-phoenix-channels' | awk '{print $3}' | xargs sudo docker image rm
```

Being able to test the Phoenix Channels websocket from Postman isn't the only option, as per the next section.

[TOC](#toc---table-of-contents)


## Testing with a Mobile App

To test the echo chamber functionality, that uses Phoenix channels via websockets, you need to follow [this instructions](https://github.com/approov/quickstart-flutter-elixir-phoenix-channels/blob/master/ECHO-CHAMBER-EXAMPLE.md#try-the-echo-chamber-app-without-approov) to run the Echo Chamber mobile app example for this backend.


[TOC](#toc---table-of-contents)
