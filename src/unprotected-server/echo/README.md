# Unprotected Server Example

The unprotected example is the base reference to build the [Approov protected servers](/src/approov-protected-server/). This a very basic Elixir Phoenix Channels API server.


## TOC - Table of Contents

* [Why?](#why)
* [How it Works?](#how-it-works)
* [Requirements](#requirements)
* [Try It](#try-it)


## Why?

To be the starting building block for the [Approov protected servers](/src/approov-protected-server/echo), that will show you how to lock down your API server to your mobile app. Please read the brief summary in the [README](/README.md#why) at the root of this repo or visit our [website](https://approov.io/product.html) for more details.

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


## Try It

All the following shell commands will assume that you have your terminal open at the `src/approov-protected-server/token-check/echo` folder.

### Create the `.env` File

First, create the `.env` from `.env.example`:

```text
cp .env.example .env
```

Now, edit the `.env` file and adjust the secrets accordingly to the provided instructions in the comments.

### Run the Server with your Elixir Stack

> **IMPORTANT:** If you already have run the server with the Elixir docker stack we provide via the `docker-compose.yml` file then you need to delete the `_build` and `deps` folders.

First, you need to set the variables from the recently created `.env` file in your environment:

```text
export $(grep -v '^#' .env | xargs -0)
```

Next, you need to install the dependencies with:

```text
mix deps.get
```

Now, you can run this server with an interactive `iex` shell:

```text
iex -S mix phx.server
```

[TOC](#toc---table-of-contents)

### Run the Server with the Provided Elixir Docker Stack

> **IMPORTANT:** If you already have run the server with your local Elixir stack then before you try the docker stack you need to delete the `_build` and `deps` folders.

First, you need to install the dependencies with:

```text
sudo docker-compose run --rm approov-token-protected-dev mix deps.get
```

Now, run the server with an interactive `iex` shell inside the docker container:

```text
sudo docker-compose run --rm --service-ports approov-token-protected-dev iex -S mix phx.server
```

Or, run the server without an interactive `iex` shell:

```text
sudo docker-compose up
```

When you finish testing you may want to completely remove the docker stack:

```text
sudo docker-compose down
docker image ls | grep 'approov/quickstart-elixir-phoenix-channels' | awk '{print $3}' | xargs sudo docker image rm
```

[TOC](#toc---table-of-contents)

### Test with the Echo Chamber Mobile App

Finally, you can test that it works by following [this instructions](https://github.com/approov/quickstart-flutter-elixir-phoenix-channels/blob/master/src/echo-chamber-app/README.md#try-the-echo-chamber-mobile-app-without-approov) to run the Echo Chamber mobile app example for this quickstart example backend.


[TOC](#toc---table-of-contents)
