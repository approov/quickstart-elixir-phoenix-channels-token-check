#!/usr/bin/env bash
# Dual-purpose orchestrator: on the host it builds/runs the Docker container,
# and inside the container it starts the application command with optional
# readiness checks and log attachment.
set -euo pipefail

requirement_check() { # verify command exists on PATH
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required command: ${cmd}"
  fi
}
fail() { echo "ERROR: $*" >&2; exit 1; } # uniform error output + exit
info() { echo "info $*"; }               # lightweight logging helper

# Globals configured via environment overrides
RUN_MODE="${RUN_MODE:-host}"                       # host orchestrator vs container entrypoint
APP_START_CMD="${APP_START_CMD:-}"                 # command executed when inside container                       
FOLLOW_LOGS="${FOLLOW_LOGS:-true}"                 # toggle docker logs -f attachment
HOST_PORT="${HOST_PORT:-8080}"                     # host-facing port (e.g., http://localhost:3000)
WAIT_URL="${WAIT_URL:-http://localhost:${HOST_PORT}/approov-state}" # readiness probe target
WAIT_TIMEOUT="${WAIT_TIMEOUT:-60}"                   # how long to wait before failing readiness
WAIT_INTERVAL="${WAIT_INTERVAL:-2}"                   # delay between readiness checks
CONTAINER_PORT="${CONTAINER_PORT:-$HOST_PORT}"       # container listener, defaults to host port
IMAGE_NAME="${IMAGE_NAME:-approov-quickstart-elixir-phoenix-channels}" # Docker image name
CONTAINER_NAME="${CONTAINER_NAME:-approov-quickstart-elixir-phoenix-channels-app}"
ENV_FILE="${ENV_FILE:-.env}"
RUNTIME_BIN_DIR="${RUNTIME_BIN_DIR:-}"            # optional runtime-specific bin path

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

strip_wrapping_quotes() {
  local value="$1"
  if [[ "$value" =~ ^\".*\"$ ]] || [[ "$value" =~ ^\'.*\'$ ]]; then
    value="${value:1:-1}"
  fi
  printf '%s' "$value"
}

validate_approov_secret_env() {
  local env_file="$1" key="$2" placeholder="$3"
  local raw_value
  local secret_value

  if ! grep -Eq "^[[:space:]]*${key}=" "$env_file"; then
    fail "${key} is missing in ${env_file}. Set ${key}=<base64url_secret> before running."
  fi

  raw_value="$(
    grep -E "^[[:space:]]*${key}=" "$env_file" |
      tail -n 1 |
      sed -E "s/^[[:space:]]*${key}=//"
  )"

  secret_value="$(trim_whitespace "$raw_value")"
  secret_value="$(strip_wrapping_quotes "$secret_value")"
  secret_value="$(trim_whitespace "$secret_value")"

  if [[ -z "$secret_value" || "$secret_value" == "$placeholder" ]]; then
    fail "${key} is not set. Please set ${key}=<base64url_secret> in ${env_file} before running."
  fi
}

in_container() {
  [[ "$RUN_MODE" == "container" ]] || [[ -f "/.dockerenv" ]]
}

if in_container; then
  [[ -n "$APP_START_CMD" ]] || fail "APP_START_CMD must be provided to run the server"
  if [[ -n "$RUNTIME_BIN_DIR" ]]; then
    export PATH="${RUNTIME_BIN_DIR}:$PATH" # e.g., RUNTIME_BIN_DIR=/usr/local/go/bin to expose runtime binaries for golang
  fi
  # Allow Docker env-file values that require quotes for dotenv parsers.
  if [[ "$APP_START_CMD" =~ ^\".*\"$ ]] || [[ "$APP_START_CMD" =~ ^\'.*\'$ ]]; then
    APP_START_CMD="${APP_START_CMD:1:-1}"
  fi
  info "Container starting application: ${APP_START_CMD}"
  exec bash -c "$APP_START_CMD"
fi

requirement_check docker
if ! command -v approov >/dev/null 2>&1; then
  info "Approov CLI not found; continuing without CLI checks (tests may need it)"
fi

[[ -f "$ENV_FILE" ]] || fail "$ENV_FILE not found. Run cp .env.example .env first."
[[ -f Dockerfile ]] || fail "Dockerfile not found in $(pwd)"
validate_approov_secret_env \
  "$ENV_FILE" \
  "${APPROOV_SECRET_ENV:-APPROOV_BASE64URL_SECRET}" \
  "${APPROOV_SECRET_PLACEHOLDER:-approov_base64url_secret_here}"

if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
  info "Removing stale container ${CONTAINER_NAME}"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

info "Building ${IMAGE_NAME}"
docker build -t "$IMAGE_NAME" . || fail "Docker build failed"

info "Starting ${CONTAINER_NAME} on host port ${HOST_PORT}, container port ${CONTAINER_PORT}"
docker run -d \
  --name "$CONTAINER_NAME" \
  --env-file "$ENV_FILE" \
  -e RUN_MODE=container \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  "$IMAGE_NAME" >/dev/null || fail "Failed to start container ${CONTAINER_NAME}"

wait_for_service() {
  local url="$1" timeout="$2" interval="$3" elapsed=0
  info "Waiting for application to become ready at ${url}"
  until curl -fsS "$url" >/dev/null 2>&1; do
    if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
      docker logs --tail 200 "$CONTAINER_NAME" >&2 || true
      fail "Container ${CONTAINER_NAME} exited before becoming ready."
    fi

    sleep "$interval"
    elapsed=$((elapsed + interval))
    if (( elapsed >= timeout )); then
      docker logs --tail 200 "$CONTAINER_NAME" >&2 || true
      fail "Application did not become ready within ${timeout}s (last url: ${url})"
    fi
  done
  info "Application is ready"
}

wait_for_service "$WAIT_URL" "$WAIT_TIMEOUT" "$WAIT_INTERVAL"

if [[ "$FOLLOW_LOGS" == "true" ]]; then
  info "Container logs (Ctrl+C to stop):"
  docker logs -f "$CONTAINER_NAME"
else
  info "Skipping container logs attachment."
fi
