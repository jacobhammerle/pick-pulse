#!/usr/bin/env bash
# One-off demo: a QA agent explores a feature on an EAS cloud
# simulator, then a second agent reads the session log and writes a
# deterministic Maestro flow from it.
#
# Usage:
#   bash scripts/agent/qa-to-maestro.sh "<feature>" ["<extra guidance>"]
#   PR_NUMBER=<n> bash scripts/agent/qa-to-maestro.sh ["<feature>"] ["<guidance>"]
#
#   e.g.  bash scripts/agent/qa-to-maestro.sh "the pick slip payout flow" \
#           "2 picks must show x3 and a dollar total; do not open settings"
#   e.g.  PR_NUMBER=12 bash scripts/agent/qa-to-maestro.sh
#
# In PR mode the QA agent reads the PR's diff, works out what
# user-visible behavior changed, and tests exactly that. The build is
# matched to the PR's head commit when possible.
#
# Runs locally on a machine with `eas` and `claude` logged in; PR mode
# also needs GITHUB_TOKEN and GH_REPO.
# Optional: BUILD_ID env var to pin a specific simulator build;
# otherwise the newest finished preview-simulator build is used.
set -euo pipefail

FEATURE="${1:-}"
GUIDANCE="${2:-}"
PR_NUMBER="${PR_NUMBER:-}"
if [ -z "$FEATURE" ] && [ -z "$PR_NUMBER" ]; then
  echo 'usage: qa-to-maestro.sh "<feature to QA>" ["<extra guidance>"]' >&2
  echo '   or: PR_NUMBER=<n> qa-to-maestro.sh ["<feature>"] ["<guidance>"]' >&2
  exit 1
fi

# agent-device@0.20.4 is broken (missing @agent-device/ad-script).
# Pin 0.20.3 for both the remote daemon (--package-version) and the
# local CLI until it is fixed. device.sh reads the same variable.
export AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-0.20.3}"

BUNDLE_ID="com.jacobhammerle.pickpulse"

QA_DIR="$(pwd)/qa-run"
rm -rf "$QA_DIR"
mkdir -p "$QA_DIR"
export QA_LOG_FILE="$QA_DIR/device-log.md"

# PR mode: fetch the PR's title, head commit, and diff.
PR_TITLE=""
PR_SHA=""
if [ -n "$PR_NUMBER" ]; then
  PR_JSON=$(node scripts/agent/gh.mjs get-pr "$PR_NUMBER")
  PR_TITLE=$(node -e "console.log(JSON.parse(process.argv[1]).title)" "$PR_JSON")
  PR_SHA=$(node -e "console.log(JSON.parse(process.argv[1]).sha ?? '')" "$PR_JSON")
  node scripts/agent/gh.mjs get-pr-diff "$PR_NUMBER" > "$QA_DIR/pr-diff.patch"
  echo "PR #${PR_NUMBER}: ${PR_TITLE} (head ${PR_SHA})"
  if [ -z "$FEATURE" ]; then
    FEATURE="the changes in PR #${PR_NUMBER}: ${PR_TITLE}"
  fi
fi

# PR-mode flows carry a pr-<N>- prefix: it names the flow in the
# suite, and the workflow's loop guard keys on it.
if [ -n "$PR_NUMBER" ]; then
  SLUG="pr-${PR_NUMBER}-$(echo "$PR_TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | cut -c1-30)"
else
  SLUG=$(echo "$FEATURE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g' | cut -c1-40)
fi

SESSION_STARTED=""
cleanup() {
  if [ -n "$SESSION_STARTED" ]; then
    npx --yes eas-cli@latest simulator:stop --non-interactive || true
  fi
  printf '# managed by eas-cli\n' > .env.eas-simulator
}
trap cleanup EXIT

# 0. Preflight: is EAS Simulator enabled on this account?
AVAILABLE=$(npx --yes eas-cli@latest simulator:availability --json \
  | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
      console.log(JSON.parse(d).available === true ? 'yes' : 'no')})")
if [ "$AVAILABLE" != "yes" ]; then
  echo "EAS Simulator is not enabled on this account. Aborting." >&2
  exit 1
fi

# 1. Resolve the simulator build to test.
#    Priority: explicit BUILD_ID > a build from the PR's head commit
#    (pr-verify produced one) > newest preview-simulator build.
UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
BUILD_ID="${BUILD_ID:-}"
# A wrapping workflow can hand us junk (an uninterpolated expression,
# or the literal string "undefined" from a skipped job's output).
# Never let a non-UUID reach build:view.
if [ -n "$BUILD_ID" ] && ! [[ "$BUILD_ID" =~ $UUID_RE ]]; then
  echo "WARNING: ignoring invalid BUILD_ID '${BUILD_ID}'." >&2
  BUILD_ID=""
fi
if [ -z "$BUILD_ID" ] && [ -n "$PR_SHA" ]; then
  BUILD_ID=$(npx --yes eas-cli@latest build:list \
    --platform ios --build-profile preview-simulator \
    --status finished --git-commit-hash "$PR_SHA" \
    --limit 1 --json --non-interactive \
    | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
        try{console.log(JSON.parse(d)[0]?.id ?? '')}catch{console.log('')}})")
  if [ -z "$BUILD_ID" ]; then
    # Testing a build without the PR's changes would produce a bogus
    # flow, so fail clearly instead of falling back.
    echo "ERROR: no finished build found for PR head ${PR_SHA}." >&2
    echo "The PR's pr-verify build may still be running. Wait for it to" >&2
    echo "finish, or pass BUILD_ID=<id> from the PR's pr-verify run." >&2
    exit 1
  fi
fi
if [ -z "$BUILD_ID" ]; then
  BUILD_ID=$(npx --yes eas-cli@latest build:list \
    --platform ios --build-profile preview-simulator \
    --status finished --limit 1 --json --non-interactive \
    | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
        try{console.log(JSON.parse(d)[0]?.id ?? '')}catch{console.log('')}})")
fi
if ! [[ "$BUILD_ID" =~ $UUID_RE ]]; then
  echo "ERROR: could not resolve a finished preview-simulator build." >&2
  exit 1
fi
APP_URL=$(npx --yes eas-cli@latest build:view "$BUILD_ID" --json | node -e "
  let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
    try{console.log(JSON.parse(d).artifacts.applicationArchiveUrl ?? '')}catch{console.log('')}})")
case "$APP_URL" in
  http*) ;;
  *) echo "ERROR: could not resolve the artifact URL for build ${BUILD_ID}." >&2; exit 1;;
esac
echo "Using build $BUILD_ID"
# Record the build actually tested so a wrapping EAS workflow can run
# the generated flow against the same build.
echo "$BUILD_ID" > "$QA_DIR/build-id.txt"

# 2. Start the cloud simulator session and install the app.
printf '# managed by eas-cli\n' > .env.eas-simulator
npx --yes eas-cli@latest simulator:start \
  --platform ios \
  --type agent-device \
  --package-version "$AGENT_DEVICE_VERSION" \
  --non-interactive \
  --name "QA to Maestro: ${SLUG}"
SESSION_STARTED=1

# Surface the browser preview URL for the projector.
PREVIEW_URL=$(npx --yes eas-cli@latest simulator:get --json | node -e "
  let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{
    const find=(o)=>{ if(!o||typeof o!=='object')return '';
      for(const [k,v] of Object.entries(o)){
        if(k==='webPreviewUrl'&&v)return v;
        const r=find(v); if(r)return r; } return ''; };
    console.log(find(JSON.parse(d)))})")
if [ -n "$PREVIEW_URL" ]; then
  echo ""
  echo "==> Watch the QA agent live: $PREVIEW_URL"
  echo ""
fi

npx --yes eas-cli@latest simulator:exec \
  npx "agent-device@${AGENT_DEVICE_VERSION}" install-from-source "$APP_URL" --platform ios

# 3. Agent 1: QA the feature. Every device command goes through
#    scripts/agent/device.sh, which appends it to $QA_LOG_FILE.
QA_PROMPT=$(cat <<EOF
You are a QA tester exploring a feature of PickPulse (a sports picks
app, bundle id ${BUNDLE_ID}) on a remote iOS simulator.

Feature under test: ${FEATURE}

The app is already installed. Drive the device ONLY through this
wrapper (it logs every command for a later step — never call eas-cli
or agent-device directly):

  bash scripts/agent/device.sh <verb> [args]

Available verbs: open <bundle-id|deep-link> --platform ios,
snapshot -i, press <ref|selector>, fill <ref> "text",
screenshot <path>. The tap verb is "press", never "tap".

Do this:
1. Open the app: bash scripts/agent/device.sh open ${BUNDLE_ID} --platform ios
2. Take a snapshot (snapshot -i) before and after every action so the
   log records what was on screen. Element labels and text in these
   snapshots are the ground truth a later agent will build on.
3. Exercise the feature end to end like a careful tester: navigate to
   it, use it the way a user would, and verify the visible outcome.
4. Save a screenshot of each key screen to ${QA_DIR}/step-<n>-<name>.png.
5. When done, write ${QA_DIR}/qa-report.md containing:
   - the numbered steps you performed (one line each)
   - for each step, the exact visible text or label you tapped
   - the exact text that proved the expected outcome (quote it)
   - a final line "RESULT: PASS" or "RESULT: FAIL: <reason>"

Keep the run tight: one pass through the feature, no wandering.
EOF
)

if [ -f "$QA_DIR/pr-diff.patch" ]; then
  QA_PROMPT="$QA_PROMPT

This run targets PR #${PR_NUMBER}: ${PR_TITLE}.
Before touching the device, Read ${QA_DIR}/pr-diff.patch — the PR's
full diff. Work out what user-visible behavior it changes, write a
short numbered test plan (2-5 steps) for exactly that at the top of
${QA_DIR}/qa-report.md, then execute the plan on the device. Test the
changed behavior, not the whole app."
fi

if [ -n "$GUIDANCE" ]; then
  QA_PROMPT="$QA_PROMPT

Extra guidance from the person who triggered this run (follow it —
it overrides the general steps above where they conflict):
$GUIDANCE"
fi

echo "==> Phase 1: QA agent is exploring \"${FEATURE}\"..."
claude -p "$QA_PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Bash(bash scripts/agent/device.sh*) Read Write"

# 4. Simulator is no longer needed — stop billing before phase 2.
npx --yes eas-cli@latest simulator:stop --non-interactive || true
printf '# managed by eas-cli\n' > .env.eas-simulator

# 5. Agent 2: fresh context. Read the logs, write a Maestro flow.
mkdir -p .maestro/flows
FLOW_PATH=".maestro/flows/${SLUG}.yaml"
MAESTRO_PROMPT=$(cat <<EOF
A QA agent just tested "${FEATURE}" in the PickPulse iOS app
(appId ${BUNDLE_ID}) on a simulator. Two files record that session:

- ${QA_DIR}/device-log.md — every device command it ran, in order,
  with full output. The "snapshot -i" outputs show the UI element
  tree (labels, text, refs) at each step.
- ${QA_DIR}/qa-report.md — its own summary of steps and outcomes.

Read both files, then write a deterministic Maestro flow to
${FLOW_PATH} that replays the same test.

Rules:
1. Derive every step from what the log actually shows. Do not invent
   steps or assertions that the session does not support.
2. Session refs like @e2 are meaningless outside that session. Map
   each press/fill back to the stable visible text or accessibility
   label shown in the snapshot output, and select on that.
3. Assert the outcome the QA agent verified, using the exact text it
   quoted (regex-escape it if it contains special characters).
4. Maestro syntax reference:

   appId: ${BUNDLE_ID}
   tags:
     - generated
   ---
   - launchApp:
       clearState: true
   - assertVisible: "Some text"
   - tapOn: "Button label"
   - tapOn:
       id: "testID-value"
   - inputText: "hello"           # after tapOn a text field
   - scrollUntilVisible:
       element: "Some text"
   - takeScreenshot: step-name

5. Add a one-line YAML comment above each step saying which log step
   it replays.
6. Keep it minimal: launch, the taps that exercise the feature, the
   assertion that proves it works.
EOF
)

if [ -f "$QA_DIR/pr-diff.patch" ]; then
  MAESTRO_PROMPT="$MAESTRO_PROMPT

Context: the session verified PR #${PR_NUMBER} (\"${PR_TITLE}\").
${QA_DIR}/pr-diff.patch has the diff if you need it. The flow's
assertions must cover the behavior that PR changed — this flow is the
PR's regression test."
fi

echo "==> Phase 2: authoring the Maestro flow from the session log..."
claude -p "$MAESTRO_PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read Glob Grep Write"

if [ ! -f "$FLOW_PATH" ]; then
  echo "No flow was written to $FLOW_PATH — check the phase 2 output." >&2
  exit 1
fi

# Record where the flow landed so a wrapping EAS workflow can pick it up.
echo "$SLUG" > "$QA_DIR/slug.txt"
echo "$FLOW_PATH" > "$QA_DIR/flow-path.txt"
if [ -n "$PR_NUMBER" ]; then
  echo "$PR_NUMBER" > "$QA_DIR/pr-number.txt"
fi

echo ""
echo "==> Done."
echo "    Session log:   $QA_LOG_FILE"
echo "    QA report:     $QA_DIR/qa-report.md"
echo "    Maestro flow:  $FLOW_PATH"
echo ""
echo "To run the generated flow deterministically on EAS:"
echo "  git add $FLOW_PATH && git commit -m 'Add generated Maestro flow: ${SLUG}' && git push"
echo "  npx eas-cli@latest workflow:run .eas/workflows/maestro-e2e.yml"
