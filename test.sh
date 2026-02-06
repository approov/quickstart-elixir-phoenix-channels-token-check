#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

#######################################
# Approov demo API test harness.
#
# Description:
#   Calls unprotected and protected endpoints of the Approov demo API,
#   validates HTTP status codes and logs complete HTTP exchanges
#   (request + response) to a timestamped log file.
#
# Dependencies:
#   - bash
#   - curl
#   - approov CLI available on PATH and configured
#
# Environment:
#   BASE_URL:
#     Base URL of the API under test. Default: http://localhost:8080
#   TOKDIR:
#     Directory where temporary token files are stored. Default: .config
#     LOGDIR=${TOKDIR}/logs, LOGFILE=${LOGDIR}/<timestamp>.log
#######################################

# Constants
readonly BASE_URL="${BASE_URL:-http://localhost:8080}"
readonly TOKDIR="${TOKDIR:-.config}"
readonly LOGDIR="${TOKDIR}/logs"
readonly LOGFILE="${LOGDIR}/$(date '+%Y-%m-%d_%H-%M-%S').log"

# Globals
# is_approov_disabled:
#   Boolean flag indicating if Approov checks appear disabled
#   based on /approov-state endpoint.
is_approov_disabled=false
success_code=200
failure_code=401

# state_http_code:
#   HTTP status code from /approov-state endpoint.
state_http_code=''

#######################################
# Print error message to STDERR with timestamp.
# Globals:
#   None
# Arguments:
#   All arguments are printed as the error message.
# Outputs:
#   Writes formatted error message to STDERR.
# Returns:
#   0
#######################################
err() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

#######################################
# Ensure a required command exists on PATH.
# Globals:
#   None
# Arguments:
#   command name to check.
# Outputs:
#   Error message to STDERR if command is missing.
# Returns:
#   Exits the script with code 1 if the command is missing.
#######################################
requirement_check() {
	local cmd="$1"

	if ! command -v "${cmd}" >/dev/null 2>&1; then
		err "Missing required command: ${cmd}"
		exit 1
	fi
}

#######################################
# Generate an Approov token into an output file.
# Globals:
#   None
# Arguments:
#   output file path.
#   arguments passed to "approov token".
# Outputs:
#   Captures stdout+stderr from "approov token", takes the last non-empty
#   line as the token, and writes only that line to the output file.
# Returns:
#   0 on success.
#   1 on failure (CLI error or no token produced).
#######################################
gen_token() {
	local outfile="$1"
	shift

	set +o errexit
	local cli_output
	cli_output="$(approov token "$@" 2>&1)"
	local rc=$?
	set -o errexit

	if ((rc != 0)); then
		err "Approov CLI failed: approov token $*"
		printf '%s\n' "${cli_output}" >&2
		return 1
	fi

	# Prints notices before the token, grab the last non-empty line.
	local token
	token="$(printf '%s\n' "${cli_output}" | awk 'NF{last=$0} END{print last}')"
	if [[ -z "${token}" ]]; then
		err "Approov CLI produced no token output"
		return 1
	fi

	printf '%s\n' "${token}" >"${outfile}"
}

#######################################
# Print test result and append full HTTP exchange to a log file.
# Globals:
#   LOGFILE
#   is_approov_disabled
# Arguments:
#   $1 - test name.
#   $2 - expected HTTP status code.
#   $3 - actual HTTP status code.
#   $4 - full HTTP response (headers + body).
# Outputs:
#   Human-readable result to STDOUT.
#   Detailed log entry appended to LOGFILE.
# Returns:
#   0
#######################################
print_test_result() {
	local name="$1"
	local expected="$2"
	local status="$3"
	local resp="$4"

	local result="Failed"
	if [[ "${status}" == "${expected}" ]]; then
		result="Passed"
	fi

	echo "${name}: ${result}  (status: ${status}, expected: ${expected})"

	{
		echo "Test: ${name}"
		echo "Expected status: ${expected}"
		echo "Actual status:   ${status}"
		if [[ "${is_approov_disabled}" == "false" ]]; then
			echo "Approov State: enabled, token checks performed."
		else
			echo "Approov State: disabled, no checks performed."
		fi
		echo
		echo "HTTP exchange:"
		echo "${resp}"
		echo
	} >>"${LOGFILE}" 2>&1
}

#######################################
# Execute a curl call for a test and evaluate the result.
# Globals:
#   None
# Notes:
#   Uses print_test_result, which logs to LOGFILE and reads
#   is_approov_disabled.
# Arguments:
#   test name.
#   expected HTTP status code.
#   arguments passed to curl.
# Outputs:
#   Short result to STDOUT, full HTTP exchange appended to LOGFILE.
# Returns:
#   0 on success, curl's exit code on failure.
#######################################
run_test() {
	# shift after each grab so $1 advances (name -> expected -> rest)
	local name="$1"; shift
	local expected="$1"; shift

	local resp
	local status
	local curl_rc

	# -i: include headers, -s: silent
	set +o errexit
	resp="$(curl -i -s "$@")"
	curl_rc=$?
	set -o errexit

	if ((curl_rc != 0)); then
		err "curl failed for ${name} (rc=${curl_rc})"
		return "${curl_rc}"
	fi

	status="$(
		printf '%s\n' "${resp}" |
			grep -m1 '^HTTP/' |
			awk '{print $2}'
	)"

	print_test_result "${name}" "${expected}" "${status}" "${resp}"
}

main() {
	requirement_check "approov"
	requirement_check "curl"

	mkdir -p "${TOKDIR}" "${LOGDIR}"

	echo "Listing Approov API configuration:"
	approov api -list
	echo

	echo "Approov state check:"
	local state_response
	state_response="$(curl -i -s "${BASE_URL}/approov-state")"
	state_http_code="$(
		printf '%s\n' "${state_response}" |
			grep -m1 '^HTTP/' |
			awk '{print $2}'
	)"

	if [[ "${state_http_code}" != "200" || -z "${state_http_code}" ]]; then
		err "Failed to get Approov state from ${BASE_URL}/approov-state (status=${state_http_code:-unknown})"
		exit 1
	fi

	if grep -q '"approovEnabled":true' <<<"${state_response}"; then
		echo " Approov service: ENABLED"
		is_approov_disabled=false
	else
		echo " Approov service: DISABLED"
		is_approov_disabled=true
		failure_code=200
	fi
	echo

	# 0) Unprotected endpoint.
	run_test \
		"Unprotected request - no approov protection" \
		"${success_code}" \
		"${BASE_URL}/unprotected"

	# 1) Token check.
	gen_token \
		"${TOKDIR}/approov_token_valid" \
		-genExample \
		example.com

	# 1.1) Valid Token.
	run_test \
		"Token check - valid token" \
		"${success_code}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_valid")" \
		"${BASE_URL}/token-check"

	# 1.2) Invalid Token.
	gen_token \
		"${TOKDIR}/approov_token_invalid" \
		-genExample \
		example.com \
		-type invalid || true

	run_test \
		"Token check - invalid token" \
		"${failure_code}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_invalid")" \
		"${BASE_URL}/token-check"

	# 2) Token Binding ["Authorization"].
	local AUTH_VAL="ExampleAuthToken=="
	export HASH_INPUT="${AUTH_VAL}"

	gen_token \
		"${TOKDIR}/approov_token_bind_auth_valid" \
		-setDataHashInToken "${HASH_INPUT}" \
		-genExample \
		example.com

	# 2.1) Valid Token.
	run_test \
		"Single Binding - valid token and header" \
		"${success_code}" \
		-H "Authorization: ${AUTH_VAL}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_valid")" \
		"${BASE_URL}/token-binding"

	# 2.2) Missing Header.
	run_test \
		"Single Binding - missing Authorization header" \
		"${failure_code}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_valid")" \
		"${BASE_URL}/token-binding"

	# 2.3) Incorrect Header.
	run_test \
		"Single Binding - incorrect Authorization header" \
		"${failure_code}" \
		-H "Authorization: BadAuthToken==" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_valid")" \
		"${BASE_URL}/token-binding"

	# 2.4) Invalid Token.
	gen_token \
		"${TOKDIR}/approov_token_bind_auth_invalid" \
		-setDataHashInToken "${HASH_INPUT}" \
		-genExample \
		example.com \
		-type invalid || true

	run_test \
		"Single Binding - invalid token" \
		"${failure_code}" \
		-H "Authorization: ${AUTH_VAL}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_invalid")" \
		"${BASE_URL}/token-binding"

	# 3) Token Binding ["Authorization", "SessionId"].
	local AUTH_VAL2="ExampleAuthToken=="
	local SI_VAL="123"
	export HASH_INPUT="${AUTH_VAL2}${SI_VAL}"

	gen_token \
		"${TOKDIR}/approov_token_bind_auth_si_valid" \
		-setDataHashInToken "${HASH_INPUT}" \
		-genExample \
		example.com

	# 3.1) Valid.
	run_test \
		"Double Binding - valid token and headers" \
		"${success_code}" \
		-H "Authorization: ${AUTH_VAL2}" \
		-H "SessionId: ${SI_VAL}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_si_valid")" \
		"${BASE_URL}/token-double-binding"

	# 3.2) Missing headers.
	run_test \
		"Double Binding - missing binding headers" \
		"${failure_code}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_si_valid")" \
		"${BASE_URL}/token-double-binding"

	# 3.3) Incorrect headers.
	run_test \
		"Double Binding - incorrect binding headers" \
		"${failure_code}" \
		-H "Authorization: BadAuthToken==" \
		-H "SessionId: Bad123" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_si_valid")" \
		"${BASE_URL}/token-double-binding"

	# 3.4) Invalid token.
	gen_token \
		"${TOKDIR}/approov_token_bind_auth_si_invalid" \
		-setDataHashInToken "${HASH_INPUT}" \
		-genExample \
		example.com \
		-type invalid || true

	run_test \
		"Double Binding - invalid token" \
		"${failure_code}" \
		-H "Authorization: ${AUTH_VAL2}" \
		-H "SessionId: ${SI_VAL}" \
		-H "approov-token: $(<"${TOKDIR}/approov_token_bind_auth_si_invalid")" \
		"${BASE_URL}/token-double-binding"

	echo
	echo "Full request and response details are saved in:"
	echo "  ${LOGFILE}"
}

main "$@"
