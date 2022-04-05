#!/bin/elixir

Mix.install(
  [
    {:jason, "~> 1.2"},
    {:jose, "~> 1.11"}
  ]
)

secret = System.get_env("APPROOV_BASE64URL_SECRET") || raise "Missing APPROOV_BASE64URL_SECRET env var in your host environment."

IO.puts("\nYou need to use the authorization token returned by the Login request.\n")
authorization_token = IO.gets "Authorization Token: "

authorization_token = authorization_token |> String.trim()

pay_claim =
  :crypto.hash(:sha256, "Bearer #{authorization_token}")
  |> Base.encode64()

jwk = %{
  "kty" => "oct",
  "k" => secret
}

header = %{
  "alg" => "HS256",
  "typ" => "JWT",
}

payload = %{
  "exp" => 4516239022,
  "pay" => pay_claim
}

jwt = JOSE.JWT.sign(jwk, header, payload)

{ _, jwt_string } = JOSE.JWS.compact(jwt)

IO.puts("\nApproov Token Binding: #{jwt_string}\n")
