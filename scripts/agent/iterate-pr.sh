#!/usr/bin/env bash
# Applies a requested change to a PR branch with Claude Code.
# Requires: PR_NUMBER, INSTRUCTION, CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN, GH_REPO
set -euo pipefail

PR_JSON=$(node scripts/agent/gh.mjs get-pr "$PR_NUMBER")
BRANCH=$(node -e "console.log(JSON.parse(process.argv[1]).branch)" "$PR_JSON")

git config user.name "pickpulse-agent"
git config user.email "agent@users.noreply.github.com"
REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git"
git fetch "$REMOTE" "$BRANCH"
# The worker materializes the uploaded project as untracked files, so a
# plain checkout refuses to overwrite them. Force the branch tree, then
# drop leftover untracked files so `git add -A` cannot commit strays
# (node_modules and other ignored paths survive the clean).
git checkout -f -B "$BRANCH" FETCH_HEAD
git clean -fd

PROMPT=$(cat <<EOF
You are iterating on PR #${PR_NUMBER} of this Expo React Native app
(PickPulse, a sports picks demo).

A reviewer requested this change:

"${INSTRUCTION}"

Instructions:
1. Apply exactly what was requested. Keep the change minimal.
2. Run: npx tsc --noEmit — and make sure it passes.
3. Do NOT commit or push. Just edit the files.
EOF
)

claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read Glob Grep Edit Write Bash(npx tsc*) Bash(node*)"

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
  exit 0
fi

git commit -m "chore: apply reviewer feedback on PR #${PR_NUMBER}"
git push "$REMOTE" "HEAD:${BRANCH}"

node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Agent iteration

**Requested:** _${INSTRUCTION}_

✅ **Applied** — pushed to \`${BRANCH}\`. These re-run automatically on the new commit:

1. 🔍 **Automated code review** — Claude re-reviews the updated diff
2. 📱 **EAS cloud simulator** — the change is re-verified; fresh evidence is posted
3. 🚀 **EAS Update preview** — the per-PR preview channel is republished

_Posted by the agent-iterate EAS workflow._"
