#!/usr/bin/env bash
# Boots an EAS cloud simulator session, has Claude Code verify the PR
# on it with agent-device (screenshots + recording), deploys the
# evidence to EAS Hosting, and emits step outputs.
# Requires: BUILD_ID, PR_NUMBER, PR_TITLE, ANTHROPIC_API_KEY, EXPO_TOKEN
set -euo pipefail

EVIDENCE_DIR="$(pwd)/evidence"
mkdir -p "$EVIDENCE_DIR"

# agent-device@0.20.4 is broken (missing @agent-device/ad-script).
# Pin 0.20.3 for both the remote daemon (--package-version) and the
# CLI calls until it is fixed, then drop the pin back to latest.
AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-0.20.3}"

cleanup() {
  npx --yes eas-cli@latest simulator:stop --non-interactive || true
}
trap cleanup EXIT

# 1. Start the cloud simulator session (visible in the EAS dashboard
#    under Simulator Sessions — open it on the projector). Name it so
#    the sessions list reads like a history of verified PRs.
SESSION_NAME=$(printf 'PR #%s verify: %s' "$PR_NUMBER" "$PR_TITLE" | cut -c1-50)
printf '# managed by eas-cli\n' > .env.eas-simulator
npx --yes eas-cli@latest simulator:start \
  --platform ios \
  --type agent-device \
  --package-version "$AGENT_DEVICE_VERSION" \
  --non-interactive \
  --name "$SESSION_NAME"

# 2. Get the build artifact URL and install it on the remote simulator.
APP_URL=$(npx --yes eas-cli@latest build:view "$BUILD_ID" --json | node -e "
  let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
    const b=JSON.parse(d);
    console.log(b.artifacts.applicationArchiveUrl);
  })")
npx --yes eas-cli@latest simulator:exec \
  npx "agent-device@${AGENT_DEVICE_VERSION}" install-from-source "$APP_URL" --platform ios

# 3. Let Claude Code drive the app and collect evidence.
PROMPT=$(cat <<EOF
You are verifying a bug fix on a remote iOS simulator for PR #${PR_NUMBER}:
"${PR_TITLE}".

The app under test is PickPulse (bundle id com.jacobhammerle.pickpulse), already
installed on a remote EAS simulator. Drive it with agent-device through
eas-cli. Every device command must be run exactly like this:

  npx --yes eas-cli@latest simulator:exec npx agent-device@${AGENT_DEVICE_VERSION} <verb> [args]

Available verbs: apps, open, snapshot -i, press <ref>, fill <ref> "text",
screenshot <path>. The tap verb is "press", never "tap".

Context: before this PR, Settings was only reachable through a small
gear (⚙︎) link in the top-right of the home header. The PR moves it
into a bottom tab bar so the user can tab between Home and Settings.

Verification steps:
1. Open the app: open com.jacobhammerle.pickpulse --platform ios
2. snapshot -i to see the home screen (the picks board).
3. Check for a tab bar at the bottom of the screen with a Home tab and
   a Settings tab. No tab bar means the change is NOT working.
4. Save a screenshot to ${EVIDENCE_DIR}/1-home-with-tabs.png.
5. Press the Settings tab. Confirm the settings screen appears (it has
   the channel switching UI: a channel text field and a Switch channel
   button). Save ${EVIDENCE_DIR}/2-settings-tab.png.
6. Press the Home tab. Confirm the picks board comes back. Save
   ${EVIDENCE_DIR}/3-back-home.png.
7. Confirm the old gear (⚙︎) link is gone from the home header. If it
   is still there, note it in the verdict but do not fail on it alone.
8. Write your verdict to ${EVIDENCE_DIR}/verdict.txt as a single line:
   "PASS: <short reason>" or "FAIL: <short reason>". PASS means: tab
   bar present, and tabbing to Settings and back to Home both work.
EOF
)

claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Bash(npx*) Read Write"

VERDICT=$(cat "$EVIDENCE_DIR/verdict.txt" 2>/dev/null || echo "FAIL: no verdict written")

# 4. Build a small static evidence site and deploy it to EAS Hosting.
node scripts/agent/build-evidence-site.mjs "$EVIDENCE_DIR" "$PR_NUMBER" "$VERDICT"
# eas deploy path.join()s --export-dir onto the project dir, so an absolute
# path gets doubled and "not found". Pass it relative to the project root.
DEPLOY_JSON=$(npx --yes eas-cli@latest deploy \
  --export-dir "evidence/site" \
  --alias "pr-${PR_NUMBER}-evidence" \
  --non-interactive --json)
EVIDENCE_URL=$(node -e "
  const d=JSON.parse(process.argv[1]);
  console.log(d.url ?? d.deploymentUrl ?? '');
" "$DEPLOY_JSON")

# 5. Expose outputs to the github-comment job.
set-output evidence_url "$EVIDENCE_URL"
set-output verdict "$VERDICT"
