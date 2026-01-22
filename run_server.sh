#!/usr/bin/env bash
# Host-side wrapper: sets FOLLOW_LOGS (default true) and hands execution to scripts/build.sh,
# which handles image build/run plus container log tailing.
set -euo pipefail

FOLLOW_LOGS="${FOLLOW_LOGS:-true}" ./scripts/build.sh
