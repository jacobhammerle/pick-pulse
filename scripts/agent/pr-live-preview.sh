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
#                          name such as "iPhone 16 Pro"; empty = runner default)
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

# --build-id installs and launches the binary before the session is
# ready — no artifact download, upload, or manual launch needed.
# --device is only sent when requested; the runner otherwise picks one.
# The runner does not reject an unknown device name (the session still
# boots), so the comment reports the name as requested.
START_ARGS=(--platform ios --type agent-device
  --package-version "$AGENT_DEVICE_VERSION"
  --build-id "$BUILD_ID"
  --max-duration-minutes "$DURATION_MINUTES"
  --name "$SESSION_NAME" --json --non-interactive)
if [ -n "$DEVICE" ]; then
  START_ARGS+=(--device "$DEVICE")
fi
echo "Starting a $DURATION_MINUTES-minute $DEVICE_LABEL session with build $BUILD_ID"
START_JSON=$(npx --yes eas-cli@latest simulator:start "${START_ARGS[@]}")
SESSION_ID=$(printf '%s' "$START_JSON" | json_field id)
echo "Session $SESSION_ID created; waiting for it to come alive..."

PREVIEW_URL=""
for i in $(seq 1 64); do
  S=$(npx --yes eas-cli@latest simulator:get --id "$SESSION_ID" --json --non-interactive 2>/dev/null || true)
  STATUS=$(printf '%s' "$S" | json_field status || true)
  if [ "$STATUS" = "IN_PROGRESS" ]; then
    PREVIEW_URL=$(printf '%s' "$S" | json_field remoteConfig.webPreviewUrl || true)
    [ -n "$PREVIEW_URL" ] && break
  fi
  case "$STATUS" in
    STOPPED|ERRORED) echo "Simulator session failed to boot ($STATUS)."; exit 1 ;;
  esac
  sleep 15
done
[ -n "$PREVIEW_URL" ] || { echo "Session not ready in time."; exit 1; }

DEVICE_LINE=""
if [ -n "$DEVICE" ]; then
  DEVICE_LINE="- 📱 **Device** — requested \`$DEVICE\`; an unknown name is not rejected, so check the device in the preview
"
fi

node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Live preview

**Status:** ✅ Ready — **[open the iOS simulator in your browser]($PREVIEW_URL)**

This PR's app is installed and running on an EAS cloud $DEVICE_LABEL.

${DEVICE_LINE}- ⏱️ **Session length** — stops by itself after $DURATION_MINUTES minutes; stop it early with \`eas simulator:stop --id $SESSION_ID\`
- 🔁 **Fresh session** — comment \`@expo-bot preview [minutes] [device]\` again, e.g. \`@expo-bot preview iPhone 16 Pro for 45\`

_Posted by the pr-live-preview EAS workflow._"
COMMENT_POSTED=1

set-output preview_url "$PREVIEW_URL"
set-output session_id "$SESSION_ID"
set-output device_label "$DEVICE_LABEL"
echo ""
echo "🌐 Live preview ($DEVICE_LABEL): $PREVIEW_URL"
