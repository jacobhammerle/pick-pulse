#!/usr/bin/env bash
# Boots an EAS cloud simulator with the binary the workflow repacked (or
# built) with this PR's JS, lets Claude Code verify the PR (screenshots
# into evidence/), deploys the evidence site to EAS Hosting, comments the
# result on the PR, and emits step outputs.
# Requires: BUILD_ID, PR_NUMBER, GH_REPO, GITHUB_TOKEN, EXPO_TOKEN,
#           CLAUDE_CODE_OAUTH_TOKEN
# Optional: INSTRUCTION (reviewer guidance; may be the raw @expo-bot comment)
#           BUILD_STATUS, REPACK_STATUS (upstream job statuses)
#           HEAD_REPO, BASE_REPO (fork guard; empty when unknown)
#           UPDATE_CHANNEL (channel the workflow published the PR's JS to;
#           default pr-<PR_NUMBER>), UPDATE_GROUP_ID (that publish's update
#           group, for a deep link) — echoed back as the channel to surf to
#           AGENT_DEVICE_VERSION (default latest)
set -euo pipefail

APP_ID="com.jacobhammerle.pickpulse"
EVIDENCE_DIR="evidence"
# shellcheck disable=SC1091
. scripts/agent/comment-lib.sh
export AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-latest}"
# The verifier drives the device through scripts/agent/device.sh, which
# appends every command and its output here.
export QA_LOG_FILE=/tmp/verify-device-log.md

for v in GITHUB_TOKEN GH_REPO EXPO_TOKEN CLAUDE_CODE_OAUTH_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "$v is not set; add it as an EAS environment variable (production)."
    exit 1
  fi
done

# Public-repo guard: this script runs with this project's secrets. Refuse a
# PR whose head repo is detectably not this repo. Either name may arrive
# empty or uninterpolated (comment-triggered and manual runs have no
# pull_request payload; fork PRs never trigger comment runs), so only a
# visible mismatch stops the run.
case "${HEAD_REPO:-}${BASE_REPO:-}" in *'${{'*) HEAD_REPO=''; BASE_REPO='' ;; esac
if [ -n "${HEAD_REPO:-}" ] && [ -n "${BASE_REPO:-}" ] && [ "$HEAD_REPO" != "$BASE_REPO" ]; then
  echo "PR head is fork '$HEAD_REPO'; refusing to run agent scripts with secrets."
  exit 1
fi

# The session bills until stopped, and a run that dies before commenting
# would leave the PR silent; the trap covers both. It tells the truth: a
# reached verdict is reported as the verdict even when a later step
# (evidence deploy, comment) failed.
COMMENT_POSTED=""
cleanup() {
  code=$?
  npx --yes eas-cli@latest simulator:stop --non-interactive >/dev/null 2>&1 || true
  if [ "$code" -ne 0 ] && [ -z "$COMMENT_POSTED" ]; then
    if [ -s /tmp/verify-verdict.md ]; then
      node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent verification

**Verdict:** $(verdict_badge "$(normalize_verdict "$(head -n 1 /tmp/verify-verdict.md)")")

⚠️ **A later step failed after the verdict** — the full report is in the pr-verify run logs on EAS.

_Posted by the pr-verify EAS workflow._" || true
    else
      node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent verification

⚠️ **Verification errored before a verdict** — see the pr-verify run logs on EAS, then comment \`@expo-bot review\` to retry.

_Posted by the pr-verify EAS workflow._" || true
    fi
  fi
}
trap cleanup EXIT

if [ "${BUILD_STATUS:-}" = "failure" ]; then
  echo "Upstream simulator build failed; nothing to verify."
  exit 1
fi
if [ "${REPACK_STATUS:-}" = "failure" ]; then
  echo "Repacking the binary with the PR's JS failed; nothing to verify."
  exit 1
fi
if [ -z "${BUILD_ID:-}" ]; then
  echo "BUILD_ID is empty; no simulator binary to verify against."
  exit 1
fi

mkdir -p "$EVIDENCE_DIR"
rm -f /tmp/verify-verdict.md "$QA_LOG_FILE"
INSTRUCTION=$(bot_instruction "${INSTRUCTION:-}" review)

# PR context for the verifier prompt and the session name.
node scripts/agent/gh.mjs get-pr "$PR_NUMBER" > /tmp/pr-info.json
PR_TITLE=$(node -e "console.log(JSON.parse(require('fs').readFileSync('/tmp/pr-info.json','utf8')).title)")
node scripts/agent/gh.mjs get-pr-diff "$PR_NUMBER" > /tmp/pr.diff
if [ "$(wc -c < /tmp/pr.diff)" -gt 150000 ]; then
  head -c 150000 /tmp/pr.diff > /tmp/pr.diff.capped
  printf '\n\n[diff truncated at 150 kB]\n' >> /tmp/pr.diff.capped
  mv /tmp/pr.diff.capped /tmp/pr.diff
fi

echo "Verifying binary $BUILD_ID (repacked or built with this PR's JS)"

# Name the session so the dashboard reads like a history of verified PRs.
# --build-id installs and launches the binary before the session is
# ready — no artifact download, upload, or manual launch needed.
SESSION_NAME=$(printf 'PR #%s verify: %s' "$PR_NUMBER" "$PR_TITLE" | cut -c1-50)
printf '# managed by eas-cli\n' > .env.eas-simulator
npx --yes eas-cli@latest simulator:start --platform ios --type agent-device \
  --package-version "$AGENT_DEVICE_VERSION" \
  --build-id "$BUILD_ID" \
  --max-duration-minutes 30 --non-interactive --name "$SESSION_NAME"

LIVE=""
for i in $(seq 1 64); do
  S=$(npx --yes eas-cli@latest simulator:get --json --non-interactive 2>/dev/null || true)
  if echo "$S" | grep -q '"status": "IN_PROGRESS"' && echo "$S" | grep -q remoteConfig; then
    LIVE=1
    break
  fi
  if echo "$S" | grep -qE '"status": "(STOPPED|ERRORED)"'; then
    echo "Simulator session failed to boot."
    exit 1
  fi
  sleep 15
done
[ -n "$LIVE" ] || { echo "Session not ready in time."; exit 1; }

# Deterministic floor beneath the AI verifier: the app is in the
# foreground and rendered a UI tree at all. `open` also returns the
# initial interactive snapshot, which the prompt hands to the agent.
sleep 10
SNAPSHOT=$(bash scripts/agent/device.sh open "$APP_ID" --platform ios || true)
printf '%s\n' "$SNAPSHOT" > /tmp/home-snapshot.txt
if [ -z "$SNAPSHOT" ]; then
  echo "❌ Verification failed: empty UI snapshot after launch."
  exit 1
fi

# The verifier prompt lives in the repo (YAML has a 16 kB server limit).
cp .eas/expo-bot-verify-prompt.md /tmp/verify-prompt.md
printf '\nThe PR under test is #%s: "%s".\n' "$PR_NUMBER" "$PR_TITLE" >> /tmp/verify-prompt.md
if [ -n "$INSTRUCTION" ]; then
  printf '\nReviewer guidance for this run (from the @expo-bot comment): %s\n' "$INSTRUCTION" >> /tmp/verify-prompt.md
fi

echo "Running Claude verifier..."
# The verdict file is the contract; Claude's own exit code is not. timeout
# is the hard backstop: a hung agent gets killed, leaves no verdict, and
# the run fails closed.
timeout 20m claude -p "$(cat /tmp/verify-prompt.md)" \
  --permission-mode acceptEdits \
  --max-turns 120 \
  --output-format stream-json --verbose \
  --allowedTools "Bash(bash scripts/agent/device.sh*),Read,Glob,Grep,Write" \
  | node .eas/gate-log-format.js || true

if [ ! -s /tmp/verify-verdict.md ]; then
  echo "FAIL: verifier produced no verdict file (agent error, timeout, or runaway)." > /tmp/verify-verdict.md
fi
# normalize_verdict makes line 1 unambiguous: "PASS: FAIL: ..." is a FAIL,
# not the PASS a plain prefix test would read.
VERDICT_LINE=$(normalize_verdict "$(head -n 1 /tmp/verify-verdict.md)")
echo "================ VERDICT ================"
cat /tmp/verify-verdict.md
echo "========================================="

# The evidence site, by eas-simulator-evidence: the session's own
# artifacts (cpu/mem samples, the action timeline, the screen recording)
# plus the screenshots and the verifier's report, deployed to EAS Hosting
# under a per-PR alias. --stop: the tool stops the session as soon as the
# verdict is in (it bills until then), then waits for its artifacts. A
# missing artifact never fails verification; a build or deploy failure
# does. --json puts the summary on the last stdout line.
RUN_JSON=$(evidence_tool run "$EVIDENCE_DIR" --stop \
  --subject "PR #${PR_NUMBER}" \
  --verdict "$VERDICT_LINE" --verdict-file /tmp/verify-verdict.md \
  --agent expo-bot --lane "PR #${PR_NUMBER}" --build-id "$BUILD_ID" \
  --deploy-alias "pr-${PR_NUMBER}-evidence" --json)
EVIDENCE_URL=$(node -e "
  const last = process.argv[1].trim().split('\n').pop();
  console.log(JSON.parse(last).url ?? '');
" "$RUN_JSON")
echo "Evidence site: $EVIDENCE_URL"

# The workflow's update job published this PR's JS to its own channel.
# That channel is the answer to "where do I see this?": the Preview
# Channel screen on any release build (the TestFlight install included)
# can surf to it live. The group id gives a deep link to the exact update.
UPDATE_CHANNEL=${UPDATE_CHANNEL:-pr-${PR_NUMBER}}
UPDATE_URL=""
if [[ "${UPDATE_GROUP_ID:-}" =~ ^[0-9a-fA-F-]{20,}$ ]]; then
  EXPO_PATH=$(node -e "
    const a = JSON.parse(require('fs').readFileSync('app.json','utf8')).expo;
    console.log(a.owner + '/projects/' + a.slug);
  ")
  UPDATE_URL="https://expo.dev/accounts/${EXPO_PATH}/updates/${UPDATE_GROUP_ID}"
fi
echo "Channel to surf to: $UPDATE_CHANNEL ${UPDATE_URL:+($UPDATE_URL)}"
CHANNEL_LINE="- 📡 **Channel** — \`${UPDATE_CHANNEL}\`: open PickPulse → ⚙︎ → enter the channel name → **Switch channel** to try this PR on your phone"
if [ -n "$UPDATE_URL" ]; then
  CHANNEL_LINE="${CHANNEL_LINE} ([update](${UPDATE_URL}))"
fi

# Same shape as every bot post: "## 🤖 <stage>", a verdict line, a short
# list (evidence, channel), the thumbnails, the report folded away, a
# "_Posted by_" footer. The package prints it.
node scripts/agent/gh.mjs comment "$PR_NUMBER" "$(evidence_tool comment "$EVIDENCE_DIR" "$EVIDENCE_URL" \
  --verdict "$VERDICT_LINE" --verdict-file /tmp/verify-verdict.md \
  --title "Agent verification" \
  --line "$CHANNEL_LINE" \
  --agent "the pr-verify EAS workflow")"
COMMENT_POSTED=1

set-output evidence_url "$EVIDENCE_URL"
set-output verdict "$VERDICT_LINE"
# The same line with its status emoji, for the workflow's report doc.
set-output verdict_shown "$(verdict_badge "$VERDICT_LINE")"
set-output update_channel "$UPDATE_CHANNEL"
set-output update_url "${UPDATE_URL:-(update group id not captured)}"
