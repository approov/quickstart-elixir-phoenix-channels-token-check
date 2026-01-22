# Approov Backend Quickstart - Elixir Phoenix Channels

This project provides a Phoenix Channels server that demonstrates Approov token verification for a protected backend API. It exposes endpoints that show how Approov token checks and token binding work:

- `/unprotected` - no Approov token required.
- `/token-check` - requires a valid Approov token.
- `/token-binding` - requires a valid Approov token bound to a header value.
- `/token-double-binding` - requires a valid Approov token bound to two header values.

## Approov protection overview (required logic map)

In this example, Approov protection is enforced by `ApproovQuickstartWeb.ApproovTokenVerifier` (see `lib/approov_quickstart.ex#L333-L377`), which reads the `Approov-Token` header, verifies the token signature and `exp` claim in `verify_and_decode/1` (see `lib/approov_quickstart.ex#L111-L123`), and validates token bindings via `extract_binding_value/2` and `validate_binding/2` (see `lib/approov_quickstart.ex#L130-L164`). Protected endpoints are the routes listed in `ApproovQuickstart.ProtectedRoutes` (see `lib/approov_quickstart.ex#L1-L21`) and wired into the router pipeline `:approov_protected` (see `lib/approov_quickstart.ex#L231-L254`).

- Middleware registration: `ApproovTokenVerifier` is registered once in the router pipeline and runs before protected routes.
- Failure behavior: missing/invalid token, expired token, or binding mismatch returns `401 Unauthorized` and the request is halted.
- Headers used: `Approov-Token` for the Approov JWT, plus `Authorization` and `Content-Digest` for token binding.

## Approov Token Verification Flow

1. **Token Request:** The Approov SDK inside the mobile app obtains a short-lived Approov Token (a signed JWT).
2. **Token Attachment:** The app attaches this token to each API request using the `Approov-Token` header.
3. **Server Validation:** The server validates the token signature and `exp` claim.
4. **Token Binding (Optional):** The server hashes binding headers and matches them against the token `pay` claim.
5. **Request Decision:** If checks pass → `200 OK`; otherwise → `401 Unauthorized`.

## Requirements

1. **Approov account** - sign up for an Approov trial account.
2. **Approov CLI initialized** - confirm `approov whoami` works.
3. **Install curl** - ensure the `curl` CLI is available.
4. **Create .env file** - copy `.env.example`:
   ```bash
   cp .env.example .env
   ```
5. **Configure secret** - fetch the secret and add it to `.env` (`APPROOV_BASE64URL_SECRET`):
   ```bash
   approov secret -get base64url
   ```
6. **Set Phoenix secret** - generate and add `SECRET_KEY_BASE` in `.env`:
   ```bash
   mix phx.gen.secret
   ```
7. **Register API domain** - point Approov at your backend API (default example.com):
   ```bash
   approov api -add example.com
   ```
8. **Install Docker and Docker Compose** - follow the official Docker guide.

## Try it yourself using Docker

```bash
bash run_server.sh
```

This script builds and starts the container and waits for `/approov-state` to be ready.

### Automated and Manual Testing

```bash
bash test.sh
```

The test script calls `/unprotected`, `/token-check`, `/token-binding`, and `/token-double-binding` and logs full HTTP exchanges to `.config/logs/<timestamp>.log`.

## Enable or Disable Approov Protection

When the example server is running on `localhost:8080`, you can toggle Approov protection with:

```bash
curl -X POST http://localhost:8080/approov/disable    # disable the Approov service
curl -X POST http://localhost:8080/approov/enable     # enable the Approov service
curl -X GET http://localhost:8080/approov-state       # check current state
```

## Reporting Issues

If you encounter any problems while following this guide, please open an issue in the project repository and include:

- Runtime: Elixir + Erlang versions
- Framework: Phoenix version
- Build tool: Mix
