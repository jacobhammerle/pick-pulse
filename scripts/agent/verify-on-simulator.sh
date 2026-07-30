#!/usr/bin/env bash
# Boots an EAS cloud simulator session, has Claude Code verify the PR
# on it with agent-device (screenshots + recording), deploys the
# evidence to EAS Hosting, and emits step outputs.
# Requires: BUILD_ID, PR_NUMBER, PR_TITLE, ANTHROPIC_API_KEY, EXPO_TOKEN
set -euo pipefail

EVIDENCE_DIR="$(pwd)/evidence"
mkdir -p "$EVIDENCE_DIR"

cleanup() {
  npx --yes eas-cli@latest simulator:stop --non-interactive || true
}
trap cleanup EXIT

# 1. Start the cloud simulator session (visible in the EAS dashboard
#    under Simulator Sessions — open it on the projector).
printf '# managed by eas-cli\n' > .env.eas-simulator
npx --yes eas-cli@latest simulator:start \
  --platform ios \
  --type agent-device \
  --non-interactive

# 2. Get the build artifact URL and install it on the remote simulator.
APP_URL=$(npx --yes eas-cli@latest build:view "$BUILD_ID" --json | node -e "
  let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
    const b=JSON.parse(d);
    console.log(b.artifacts.applicationArchiveUrl);
  })")
npx --yes eas-cli@latest simulator:exec \
  npx agent-device@latest install-from-source "$APP_URL" --platform ios

# 3. Let Claude Code drive the app and collect evidence.
PROMPT=$(cat <<EOF
You are verifying a bug fix on a remote iOS simulator for PR #${PR_NUMBER}:
"${PR_TITLE}".

The app under test is PickPulse (bundle id com.jacobhammerle.pickpulse), already
installed on a remote EAS simulator. Drive it with agent-device through
eas-cli. Every device command must be run exactly like this:

  npx --yes eas-cli@latest simulator:exec npx agent-device@latest <verb> [args]

Available verbs: apps, open, snapshot -i, press <ref>, fill <ref> "text",
screenshot <path>. The tap verb is "press", never "tap".

Verification steps:
1. Open the app: open com.jacobhammerle.pickpulse --platform ios
2. snapshot -i to see the board.
3. Add at least 2 picks by pressing More/Less buttons on prop cards.
4. Open the slip (the "View Slip" bar at the bottom).
5. Check the payout row: it must show a real multiplier (like ×3) and a
   real dollar total (like \$30.00). "NaN", "undefined", or a missing
   value means the bug is NOT fixed.
6. Save screenshots of the board and the slip to ${EVIDENCE_DIR}/board.png
   and ${EVIDENCE_DIR}/slip.png.
7. Write your verdict to ${EVIDENCE_DIR}/verdict.txt as a single line:
   "PASS: <short reason>" or "FAIL: <short reason>".
EOF
)

claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Bash(npx*) Read Write"

VERDICT=$(cat "$EVIDENCE_DIR/verdict.txt" 2>/dev/null || echo "FAIL: no verdict written")

# 4. Build a small static evidence site and deploy it to EAS Hosting.
node scripts/agent/build-evidence-site.mjs "$EVIDENCE_DIR" "$PR_NUMBER" "$VERDICT"
DEPLOY_JSON=$(npx --yes eas-cli@latest deploy \
  --export-dir "$EVIDENCE_DIR/site" \
  --alias "pr-${PR_NUMBER}-evidence" \
  --non-interactive --json)
EVIDENCE_URL=$(node -e "
  const d=JSON.parse(process.argv[1]);
  console.log(d.url ?? d.deploymentUrl ?? '');
" "$DEPLOY_JSON")

# 5. Expose outputs to the github-comment job.
set-output evidence_url "$EVIDENCE_URL"
set-output verdict "$VERDICT"
