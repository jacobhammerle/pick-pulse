#!/usr/bin/env bash
# Applies a reviewer-requested change to a PR branch with Claude Code,
# gates it with tsc, pushes, and comments on the PR. The push re-triggers
# pr-verify and code-review, so review + verification follow by themselves.
# Requires: PR_NUMBER, INSTRUCTION, CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN, GH_REPO
# INSTRUCTION may be the raw "@expo-bot <change>" comment or plain text.
set -euo pipefail

# shellcheck disable=SC1091
. scripts/agent/comment-lib.sh

for v in GITHUB_TOKEN GH_REPO CLAUDE_CODE_OAUTH_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "$v is not set; add it as an EAS environment variable (production)."
    exit 1
  fi
done

INSTRUCTION=$(bot_instruction "${INSTRUCTION:-}" change)
if [ -z "$INSTRUCTION" ]; then
  node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent iteration

⚠️ **No instruction found** — say what to change, for example \`@expo-bot make the slip bar purple\`. Other commands: \`@expo-bot review [guidance]\`, \`@expo-bot preview [minutes] [device]\`, \`@expo-bot qa [guidance]\`.

_Posted by the agent-iterate EAS workflow._"
  exit 0
fi

# A run that dies before commenting would leave the PR silent.
COMMENT_POSTED=""
cleanup() {
  code=$?
  if [ "$code" -ne 0 ] && [ -z "$COMMENT_POSTED" ]; then
    node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent iteration

**Requested:** _${INSTRUCTION}_

⚠️ **The change errored before it could be pushed** — see the agent-iterate run logs on EAS (a failing \`tsc\` is the usual cause). Nothing was pushed.

_Posted by the agent-iterate EAS workflow._" || true
  fi
}
trap cleanup EXIT

PR_JSON=$(node scripts/agent/gh.mjs get-pr "$PR_NUMBER")
BRANCH=$(node -e "console.log(JSON.parse(process.argv[1]).branch)" "$PR_JSON")

git config user.name "expo-bot"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git"
git fetch "$REMOTE" "$BRANCH"
# The worker materializes the uploaded project as untracked files, so a
# plain checkout refuses to overwrite them. Force the branch tree, then
# drop leftover untracked files so `git add -A` cannot commit strays
# (node_modules and other ignored paths survive the clean).
git checkout -f -B "$BRANCH" FETCH_HEAD
git clean -fd

cat > /tmp/iterate-prompt.md <<EOF_PROMPT
You are implementing a reviewer-requested change on PR #${PR_NUMBER} of
this Expo React Native app (PickPulse, a sports picks demo; expo-router,
TypeScript; product code lives under src/).

The requested change: "${INSTRUCTION}"

Rules:
1. Make the smallest change that fully satisfies the request. Match the
   style, naming, and patterns of the surrounding code.
2. Do not touch files under .eas/, .github/, or scripts/ unless the
   request explicitly names them.
3. Run: npx tsc --noEmit — and make sure it passes.
4. Do NOT commit or push; the workflow does that.
5. If the request is unclear, already satisfied, or outside this app's
   code, make NO edits.
EOF_PROMPT

timeout 10m claude -p "$(cat /tmp/iterate-prompt.md)" \
  --permission-mode acceptEdits \
  --max-turns 60 \
  --output-format stream-json --verbose \
  --allowedTools "Read Glob Grep Edit Write Bash(npx tsc*) Bash(node*)" \
  | node .eas/gate-log-format.js || true

# Hard gate: never push code that does not type-check.
npx tsc --noEmit

git add -A

# The agent may correctly conclude the code already satisfies the request.
# That is a success, not a failure: report it and exit cleanly instead of
# letting the empty `git commit` fail the job.
if git diff --cached --quiet; then
  node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent iteration

**Requested:** _${INSTRUCTION}_

✅ **No change needed** — the current code on \`${BRANCH}\` already satisfies this request. Nothing was pushed.

_Posted by the agent-iterate EAS workflow._"
  COMMENT_POSTED=1
  exit 0
fi

git commit -m "expo-bot: ${INSTRUCTION}" \
  -m "Requested via an @expo-bot comment on PR #${PR_NUMBER}."
git push "$REMOTE" "HEAD:${BRANCH}"
COMMIT_SHA=$(git rev-parse --short HEAD)

node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent iteration

**Requested:** _${INSTRUCTION}_

✅ **Applied** — pushed \`${COMMIT_SHA}\` to \`${BRANCH}\` (type-check passed). These re-run on the new commit:

1. 🔍 **Automated code review** — Claude re-reviews the updated diff
2. 📱 **Agent verification** — the change is re-checked on an EAS cloud simulator; fresh evidence is posted
3. 📡 **Channel \`pr-${PR_NUMBER}\`** — the PR's update is republished

_Posted by the agent-iterate EAS workflow._"
COMMENT_POSTED=1
