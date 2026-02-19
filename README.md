# Approov Backend Quickstart - Elixir Phoenix Channels

This project provides a server-side example of Approov token verification for a protected backend API. It exposes a simple API that verifies Approov tokens before granting access to protected endpoints and demonstrates how the endpoints behave under the current Approov configuration:

 - `/unprotected` - no Approov token required.
 - `/token-check` - requires a valid Approov token.
 - `/token-binding` - requires a valid Approov token which is bound to a header value.
 - `/token-double-binding` - requires a valid Approov token which is bound to two header values.

## WebSocket (Channels)

`/socket` requires a valid Approov token. If token binding is enabled, include `authorization` (required) and optionally `sessionid` (double binding when present).

Example (double binding):
```text
ws://localhost:8080/socket/websocket?approov_token=YOUR_TOKEN&authorization=ExampleAuthToken==&sessionid=123
```

*Generate a valid Approov token bound to the `Authorization` and `SessionId` headers:*

```bash
approov token -setDataHashInToken ExampleAuthToken==123 -genExample example.com
```

Quick test with `wscat` (same URL as above; `=` must be URL-encoded):
```bash
wscat -c "ws://localhost:8080/socket/websocket?approov_token=YOUR_TOKEN&authorization=ExampleAuthToken%3D%3D&sessionid=123"
```

Then, in the same `wscat` session:
```json
{"topic":"echo:lobby","event":"phx_join","payload":{},"ref":1}
{"topic":"echo:lobby","event":"echo","payload":{"msg":"hi"},"ref":2}
```

You can also run:
```bash
bash ws-test.sh
```
This performs a WebSocket smoke test (connect, join, echo) using an Approov token and binding values based on `/approov-state`.

In this example, Approov token check is implemented in `ApproovApplication.ex`. The responsibilities break down as follows:

1. **JWT Approov Token validation (signature + expiry)** is implemented in
   [verify_token/1](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L80-L89). It verifies the HS256 signature and rejects tokens that are missing or past `exp` via [verify_and_decode/1](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L125-L138).

2. **Token binding (`pay` + hash)** is handled by
  [validate_binding/2](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L226-L237). It computes `Base.encode64(:crypto.hash(:sha256, binding_value))` and compares it to `pay` with `Plug.Crypto.secure_compare/2`.

3. **Middleware enforcement (token + binding)** is done by
  [ApproovTokenVerifier.call/2](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L670-483), which delegates verification to [verify_http_request/1](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L466-L475) in the [:approov_protected](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L693-L695) pipeline. Requests without valid token/binding are rejected with `401`.

1. **Binding value selection (what gets hashed)** is in
  [extract_binding_value/2](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L192-L220). It uses the header list returned by [binding_headers/1](lib/ApproovApplication.ex#L222-L224), currently `Authorization` for single binding, or `Authorization + SessionId` for double binding.

1. **Protected route requirements** are defined in
  [ProtectedRoutes](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L1-L21).

1. **Protected routes are registered** in the
  [ApproovQuickstartWeb.Router](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L693-L695) scope that runs through the [:approov_protected](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/blob/refactor/elixir-phoenix-channels/lib/ApproovApplication.ex#L711-L717).

## Approov Token Verification Flow

1. **Token Request:**  
   The Approov SDK inside the mobile app securely communicates with the Approov Cloud Service to obtain a short-lived [Approov Token](https://ext.approov.io/docs/latest/approov-usage-documentation/#approov-tokens) (a signed JWT).  
   Additionally, you can use the CLI [token commands](https://ext.approov.io/docs/latest/approov-cli-tool-reference/#token-commands) to validate tokens, generate new ones, and set the data hash.

2. **Token Attachment:**  
   The app attaches this token to every API request using the `Approov-Token` HTTP header.

3. **Server Validation:**  
   The [server verifies](https://ext.approov.io/docs/latest/approov-usage-documentation/#approov-architecture) the token using the shared Approov secret, checking its:
    - Signature authenticity
    - Expiration (`exp` claim)
    - Other claims if configured

4. **Token Binding (Optional):**  
   [Token binding](https://ext.approov.io/docs/latest/approov-usage-documentation/#token-binding) is configured by the app via the Approov SDK, which hashes a chosen binding value (for example the `Authorization` header) and embeds it into the Approov token.  
   The protected API then computes the same hash from the incoming request and verifies that it matches the `pay` claim, preventing token reuse or replay attacks. For local testing, you can also generate example tokens with a binding using the Approov CLI.

5. **Request Decision:**   
      If all checks pass → the request is trusted and processed `200 OK`.   
      If validation fails → the server responds with `401 Unauthorized`.

## Requirements:

1. ***Approov account*** - If you're new, sign up for an [Approov trial account](https://approov.io/signup).
2. ***Approov CLI initialized*** - Follow the [installation guide](https://ext.approov.io/docs/latest/approov-installation/#initializing-the-approov-cli) and confirm `approov whoami` works.
3. ***Install curl*** - Ensure the `curl` CLI is available.
4. ***Create .env file*** - copy `.env.example` so there is a place to store the secret key.
    ```bash
    cp .env.example .env
    ```

5. ***Configure secret*** - fetch the secret and add it to `.env` (`APPROOV_BASE64URL_SECRET`):
   ```bash
   approov secret -get base64url
   ```

6. ***Register API domain*** - point Approov at your backend API (default example.com):
   ```bash
   approov api -add example.com
   ```

7. ***Install Docker and Docker Compose*** - follow the official guide: [Docker docs](https://docs.docker.com/get-started/get-docker/)

## Try it yourself using Docker

*If you have all requirements, you can run*

```bash
bash run-server.sh
```

This script:
- Builds and starts the container via `scripts/build.sh` (`docker build` + `docker run`) and waits for `/approov-state` to be ready.

*Once finished, press `Ctrl+C` to stop log tailing; the container keeps running unless you stop it. Use `docker ps` to find the container name and `docker stop <container_name>` to stop it.*

### Automated and Manual Testing

*When the server is running (in a different terminal), validate the endpoints via the automated bash script or by running the manual checks below*

```bash
bash test.sh
```

This script:
- Verifies that the `approov` and `curl` commands are installed.
- Checks Approov status by calling `/approov-state` (enabled vs disabled).
- Runs endpoint tests against `/unprotected` (no token), `/token-check` (valid/invalid Approov tokens), `/token-binding` (token bound to `Authorization`), and `/token-double-binding` (token bound to `Authorization` + `SessionId`).
- Logs full request/response details to `.config/logs/<timestamp>.log`.

#### *1. Unprotected Endpoint (No Approov)*

- The client sends a normal HTTP request.
- The server **does not verify** any Approov token or extra authentication header.
- This means **any client** (even tampered or unauthorized) can call the API if they know the URL.

*The following example shows how the API responds when no Approov protection is applied.*

```bash
curl -iX GET http://localhost:8080/unprotected
```

The response will be `200 OK` for this request:
```text
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-cache
```

#### *2. Approov Token Check*

- The client includes an `Approov-Token` (a short-lived JWT) in each API request header.
- The server verifies this token using the **Approov secret key** that is securely configured on the backend and checks:
    -  Token verification - confirms the token is signed by the Approov secret.
    -  Expiration (`exp` claim) - ensures the token is still valid.
- If the token is valid → request is trusted.
- If invalid → server returns `401 Unauthorized`.
- **Purpose**: Protect API endpoints so that only authentic, unmodified Approov-integrated apps can access them.

***The following example shows how the API responds when an Approov token is required.***

*Generate a valid Approov token:*

```bash
approov token -genExample example.com
```

*Use the generated token in the `Approov-Token` header and `/token-check` endpoint.*

```bash
curl -iX GET http://localhost:8080/token-check \
     -H "Approov-Token: valid_approov_token_here"
```

The response will be `200 OK` for this request:

```text
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-cache
```

*If you use an invalid or missing token, the server will respond with `401 Unauthorized`.*

#### *3. Approov Token Binding Check*

- The client sends two headers on authenticated API calls:
    - `Approov-Token`
    - `Authorization` – your auth token value (e.g., `ExampleAuthToken==`)
- The server verifies the token and ensures that the bound value matches what the app used.
- Prevents token replay - the Approov token cannot be reused or stolen for another session.
- **Use case:** Stronger protection for authenticated API calls tied to a specific user or device.

***The following example shows how the API responds when an Approov token with binding is required.***

*Generate a valid Approov token bound to the `Authorization` header:*

```bash
approov token -setDataHashInToken ExampleAuthToken== -genExample example.com
```

*Use the generated token with binding in the Approov-Token and Authorization headers when calling the /token-binding endpoint.*

```bash
curl -iX GET http://localhost:8080/token-binding \
     -H "Approov-Token: valid_approov_token_here" \
     -H "Authorization: ExampleAuthToken=="
```

The response will be `200 OK` for this request:

```text
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-cache
```

*If you use an invalid or missing header or token, the server will respond with `401 Unauthorized`.*

#### Approov Token Binding Check with Two Different Bound Values

- The client sends three headers on authenticated API calls:
    - `Approov-Token`
    - `Authorization`
    - `SessionId` It is combined with the `Authorization` header to create a stronger binding.
- Both are included in the hash inside the Approov token. This means the server verifies a single hash that covers both authentication credentials.
- **Use case:** Stronger protection then single binding by tying both headers together.

***The following example shows how the API responds when an Approov token with two bindings is required.***

*Generate a valid Approov token bound to the `Authorization` and `SessionId` headers:*

```bash
approov token -setDataHashInToken ExampleAuthToken==123 -genExample example.com
```

*Use the generated token with two bindings in the Approov-Token and Authorization headers when calling the `/token-double-binding` endpoint.*

```bash
curl -iX GET http://localhost:8080/token-double-binding \
     -H "Approov-Token: valid_approov_token_here" \
     -H "Authorization: ExampleAuthToken==" \
     -H "SessionId: 123"
```

The response will be `200 OK` for this request.

```text
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-cache
```

*If you use an invalid or missing header or token, the server will respond with `401 Unauthorized`.*

## Enable or Disable Approov Protection      

When the example server is running on `localhost:8080`, you can toggle Approov protection with these commands:

```bash
curl -X POST http://localhost:8080/approov/disable    # disable the Approov service

curl -X POST http://localhost:8080/approov/enable     # enable the Approov service

curl -X GET http://localhost:8080/approov-state       # check current state
```

*You can rerun the tests with Approov disabled to observe how the application behaves when the Approov protection is ***no longer active***.*

## Reporting Issues

**Environments where the quickstart was tested:**
```text
* Runtime: Elixir 1.19.5
* Framework: Phoenix 1.8.3
* Build Tool: Mix 1.19.5
```

If you encounter any problems while following this guide, or have any other concerns, please let us know by opening an issue [here](https://github.com/approov/quickstart-elixir-phoenix-channels-token-check/issues) and we will be happy to assist you.

## Useful Links

* [Approov QuickStarts](https://approov.io/resource/quickstarts/)
* [Approov Docs](https://ext.approov.io/docs)
* [Approov Blog](https://approov.io/blog)
* [Approov Resources](https://approov.io/resource/)
* [Approov Customer Stories](https://approov.io/customer)
* [Approov Support](https://approov.io/info/technical-support)
* [About Us](https://approov.io/company)
* [Contact Us](https://approov.io/info/contact)
