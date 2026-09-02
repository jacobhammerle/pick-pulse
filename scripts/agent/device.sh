#!/usr/bin/env bash
# Logging wrapper around agent-device on the current EAS simulator
# session. Runs the verb, prints its output as normal, AND appends the
# command + full output to QA_LOG_FILE. The QA agent drives the device
# only through this wrapper, so the log is a complete, ordered record
# of the session — the raw material a second agent turns into a
# deterministic Maestro flow.
# Requires: an active EAS simulator session (eas simulator:start).
# Optional: QA_LOG_FILE (default qa-run/device-log.md), AGENT_DEVICE_VERSION.
set -uo pipefail

QA_LOG_FILE="${QA_LOG_FILE:-qa-run/device-log.md}"
mkdir -p "$(dirname "$QA_LOG_FILE")"

# agent-device version. Default to latest; override to pin a known-good one.
AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-latest}"

TS=$(date +%H:%M:%S)
OUTPUT=$(npx --yes eas-cli@latest simulator:exec npx "agent-device@${AGENT_DEVICE_VERSION}" "$@" 2>&1)
STATUS=$?

{
  echo "## [$TS] agent-device $*"
  echo "exit: $STATUS"
  echo '```'
  echo "$OUTPUT"
  echo '```'
  echo
} >> "$QA_LOG_FILE"

echo "$OUTPUT"
exit $STATUS
