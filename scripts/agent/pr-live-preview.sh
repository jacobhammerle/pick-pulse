#!/usr/bin/env bash
# Boots an EAS cloud iOS simulator running this PR's app and comments the
# browser preview link on the PR. The binary is fingerprint-matched (and
# repacked with the PR's JS) or freshly built by the pr-live-preview
# workflow before this script runs. The session stays up until it hits its
# duration, so the reviewer can drive the app in the browser.
# Requires: BUILD_ID, PR_NUMBER, GH_REPO, GITHUB_TOKEN, EXPO_TOKEN
# Optional: PREVIEW_ARGS   the raw "@expo-bot preview ..." comment; parsed by
#                          scripts/agent/parse-preview-args.sh into the
#                          duration and device. When empty, the two below apply.
#           DURATION_MINUTES (default 30), DEVICE (an iOS Simulator device
#                          name such as "iPhone 17 Pro"; empty = runner default)
#           BUILD_STATUS, REPACK_STATUS (upstream job statuses)
#           AGENT_DEVICE_VERSION (default latest)
set -euo pipefail

AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-latest}"

for v in GITHUB_TOKEN GH_REPO EXPO_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "$v is not set; add it as an EAS environment variable (production)."
    exit 1
  fi
done

# Comment-triggered runs carry the whole comment; manual runs carry inputs.
ARGS=$(printf '%s' "${PREVIEW_ARGS:-}" | head -n 1 | sed -E 's/^@expo-bot[[:space:]]*preview[[:space:]]*//')
if [ -n "$ARGS" ] || [ -n "${PREVIEW_ARGS:-}" ]; then
  PARSED=$(bash scripts/agent/parse-preview-args.sh "$ARGS")
  echo "$PARSED"
  DURATION_MINUTES=$(printf '%s\n' "$PARSED" | sed -n 's/^duration=//p')
  DEVICE=$(printf '%s\n' "$PARSED" | sed -n 's/^device=//p')
fi
DURATION_MINUTES="${DURATION_MINUTES:-30}"
DEVICE="${DEVICE:-}"
# An uninterpolated expression is not a device name.
case "$DEVICE" in *'${{'*) DEVICE='' ;; esac

# What the PR comment calls the device: the requested name when given.
DEVICE_LABEL="iOS simulator"
if [ -n "$DEVICE" ]; then
  DEVICE_LABEL="$DEVICE (iOS simulator)"
fi
# The retry hint mirrors the comment that started this run.
RETRY_CMD="@expo-bot preview ${DURATION_MINUTES}"
if [ -n "$DEVICE" ]; then RETRY_CMD="$RETRY_CMD $DEVICE"; fi

# A run that dies before commenting would leave the PR silent, and a
# session that never went live would bill until its max duration; the trap
# covers both. A session whose link was posted is left running on purpose.
COMMENT_POSTED=""
SESSION_ID=""
cleanup() {
  code=$?
  if [ "$code" -ne 0 ] && [ -z "$COMMENT_POSTED" ] && [ -n "$SESSION_ID" ]; then
    npx --yes eas-cli@latest simulator:stop --id "$SESSION_ID" --non-interactive >/dev/null 2>&1 || true
  fi
  if [ "$code" -ne 0 ] && [ -z "$COMMENT_POSTED" ]; then
    node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Live preview

⚠️ **The $DEVICE_LABEL preview errored before it came alive** — details are in the pr-live-preview run logs on EAS. Comment \`$RETRY_CMD\` to try again, or \`@expo-bot preview\` for the default device.

_Posted by the pr-live-preview EAS workflow._" || true
  fi
}
trap cleanup EXIT

if [ "${BUILD_STATUS:-}" = "failure" ]; then
  echo "Upstream simulator build failed; nothing to preview."
  exit 1
fi
if [ "${REPACK_STATUS:-}" = "failure" ]; then
  echo "Repacking the binary with the PR's JS failed; nothing to preview."
  exit 1
fi
if [ -z "${BUILD_ID:-}" ]; then
  echo "BUILD_ID is empty; no simulator binary to preview."
  exit 1
fi

json_field() { # json_field <path> — reads JSON on stdin, prints the field
  node -e "
    let d = '';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => {
      const j = JSON.parse(d.slice(d.indexOf('{')));
      const v = process.argv[1].split('.').reduce((o, k) => (o ?? {})[k], j);
      if (v === undefined || v === null) process.exit(1);
      console.log(v);
    });
  " "$1"
}

# Name the session so the dashboard reads like a history of previewed PRs.
PR_TITLE=$(node scripts/agent/gh.mjs get-pr "$PR_NUMBER" | json_field title)
SESSION_NAME=$(printf 'PR #%s preview: %s' "$PR_NUMBER" "$PR_TITLE" | cut -c1-50)

# start_session <simulator:start args...>: create the session and wait for
# it to come alive. Sets SESSION_ID as soon as the id is known (so the trap
# can stop it) and PREVIEW_URL once the session is IN_PROGRESS. Returns 1
# when the session errors, stops, or is not ready in time.
start_session() {
  local out status i
  SESSION_ID=""
  PREVIEW_URL=""
  # The JSON (success) carries connection tokens, so it is never echoed;
  # the human-readable failure output names the session id.
  out=$(npx --yes eas-cli@latest simulator:start "$@" 2>&1) || true
  SESSION_ID=$(printf '%s' "$out" | json_field id 2>/dev/null \
    || printf '%s' "$out" | grep -oE 'id: [0-9a-f-]{20,}' | head -n 1 | cut -d' ' -f2 || true)
  if [ -z "$SESSION_ID" ]; then
    printf '%s\n' "$out" | grep -v -i token | tail -n 5
    return 1
  fi
  echo "Session $SESSION_ID created; waiting for it to come alive..."
  for i in $(seq 1 64); do
    out=$(npx --yes eas-cli@latest simulator:get --id "$SESSION_ID" --json --non-interactive 2>/dev/null || true)
    status=$(printf '%s' "$out" | json_field status || true)
    if [ "$status" = "IN_PROGRESS" ]; then
      PREVIEW_URL=$(printf '%s' "$out" | json_field remoteConfig.webPreviewUrl || true)
      [ -n "$PREVIEW_URL" ] && return 0
    fi
    case "$status" in
      STOPPED|ERRORED) echo "Simulator session $SESSION_ID failed to boot ($status)."; return 1 ;;
    esac
    sleep 15
  done
  echo "Session $SESSION_ID not ready in time."
  return 1
}

# --build-id installs and launches the binary before the session is
# ready — no artifact download, upload, or manual launch needed.
# --device is only sent when requested; the runner otherwise picks one.
START_ARGS=(--platform ios --type agent-device
  --package-version "$AGENT_DEVICE_VERSION"
  --build-id "$BUILD_ID"
  --max-duration-minutes "$DURATION_MINUTES"
  --name "$SESSION_NAME" --json --non-interactive)
echo "Starting a $DURATION_MINUTES-minute $DEVICE_LABEL session with build $BUILD_ID"
DEVICE_NOTE=""
if [ -n "$DEVICE" ]; then
  # A device name the runner does not have makes the session error within
  # seconds (seen with "iPhone 16 Pro" on 2026-10-01, when the runtime had
  # moved on to iPhone 17 devices). Rather than fail the whole preview,
  # stop the dead session, fall back to the runner's default device once,
  # and say so in the comment.
  if ! start_session "${START_ARGS[@]}" --device "$DEVICE"; then
    if [ -n "$SESSION_ID" ]; then
      npx --yes eas-cli@latest simulator:stop --id "$SESSION_ID" --non-interactive >/dev/null 2>&1 || true
    fi
    echo "The session did not come alive with --device \"$DEVICE\"; retrying with the runner's default device."
    DEVICE_NOTE="- 📱 **Device** — \`$DEVICE\` is not available on the runner, so this is the default device
"
    DEVICE=""
    DEVICE_LABEL="iOS simulator"
    start_session "${START_ARGS[@]}" || exit 1
  fi
else
  start_session "${START_ARGS[@]}" || exit 1
fi

DEVICE_LINE="$DEVICE_NOTE"
if [ -n "$DEVICE" ]; then
  DEVICE_LINE="- 📱 **Device** — \`$DEVICE\`, as requested
"
fi

node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Live preview

**Status:** ✅ Ready — **[open the iOS simulator in your browser]($PREVIEW_URL)**

This PR's app is installed and running on an EAS cloud $DEVICE_LABEL.

${DEVICE_LINE}- ⏱️ **Session length** — stops by itself after $DURATION_MINUTES minutes; stop it early with \`eas simulator:stop --id $SESSION_ID\`
- 🔁 **Fresh session** — comment \`@expo-bot preview [minutes] [device]\` again, e.g. \`@expo-bot preview iPhone 17 Pro for 45\`

_Posted by the pr-live-preview EAS workflow._"
COMMENT_POSTED=1

set-output preview_url "$PREVIEW_URL"
set-output session_id "$SESSION_ID"
set-output device_label "$DEVICE_LABEL"
echo ""
echo "🌐 Live preview ($DEVICE_LABEL): $PREVIEW_URL"
