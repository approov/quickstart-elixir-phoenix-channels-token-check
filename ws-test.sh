#!/usr/bin/env bash
set -euo pipefail

#######################################
# WebSocket smoke test for Phoenix Channels.
# Requires: wscat, approov, curl
#
# Env:
#   BASE_URL   - default http://localhost:8080
#   WS_BASE    - default ws://localhost:8080/socket/websocket
#   AUTH_VAL   - default ExampleAuthToken==
#   SESSION_ID - default 123
#######################################

requirement_check() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

BASE_URL="${BASE_URL:-http://localhost:8080}"
WS_BASE="${WS_BASE:-ws://localhost:8080/socket/websocket}"
AUTH_VAL="${AUTH_VAL:-ExampleAuthToken==}"
SESSION_ID="${SESSION_ID:-123}"

requirement_check "wscat"
requirement_check "approov"
requirement_check "curl"

state_response="$(curl -s "${BASE_URL}/approov-state")"
if ! grep -q '"approovEnabled":true' <<<"${state_response}"; then
  echo "Approov disabled; skipping WS test."
  exit 0
fi

binding_enabled=false
if grep -q '"tokenBindingEnabled":true' <<<"${state_response}"; then
  binding_enabled=true
fi

if [[ "${binding_enabled}" == "true" ]]; then
  HASH_INPUT="${AUTH_VAL}${SESSION_ID}"
  TOKEN="$(
    approov token -setDataHashInToken "${HASH_INPUT}" -genExample example.com |
      awk 'NF{last=$0} END{print last}'
  )"
  AUTH_PARAM="${AUTH_VAL//=/%3D}"
  WS_URL="${WS_BASE}?approov_token=${TOKEN}&authorization=${AUTH_PARAM}&sessionid=${SESSION_ID}"
  WS_CMD=(wscat -c "${WS_URL}")
else
  TOKEN="$(
    approov token -genExample example.com |
      awk 'NF{last=$0} END{print last}'
  )"
  WS_URL="${WS_BASE}?approov_token=${TOKEN}"
  WS_CMD=(wscat -c "${WS_URL}")
fi

join='{"topic":"echo:lobby","event":"phx_join","payload":{},"ref":1}'
echo_msg='{"topic":"echo:lobby","event":"echo","payload":{"msg":"hi"},"ref":2}'

echo "Generated token: ${TOKEN}"
output="$(
  "${WS_CMD[@]}" \
    -x "${join}" \
    -x "${echo_msg}" \
    -w 1 2>&1 || true
)"

printf '%s\n' "${output}"

if ! grep -q '"status":"ok".*"phx_reply"' <<<"${output}"; then
  echo "WS test failed: join not acknowledged" >&2
  exit 1
fi

if ! grep -q '"event":"echo"' <<<"${output}"; then
  echo "WS test failed: echo not received" >&2
  exit 1
fi

echo "WS smoke test passed."
