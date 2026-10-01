#!/usr/bin/env bash
# Runs Claude Code to fix a GitHub issue, gates it with tsc, pushes a
# fix/issue-N branch, and opens a PR that closes the issue. Comments the
# outcome on the issue either way.
# Requires: ISSUE_NUMBER, CLAUDE_CODE_OAUTH_TOKEN, GITHUB_TOKEN, GH_REPO
# Optional: INSTRUCTION (guidance; may be the raw "@expo-bot ..." comment)
set -euo pipefail

# shellcheck disable=SC1091
. scripts/agent/comment-lib.sh

for v in GITHUB_TOKEN GH_REPO CLAUDE_CODE_OAUTH_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "$v is not set; add it as an EAS environment variable (production)."
    exit 1
  fi
done

BRANCH="fix/issue-${ISSUE_NUMBER}"
INSTRUCTION=$(bot_instruction "${INSTRUCTION:-}" "")

ISSUE_JSON=$(node scripts/agent/gh.mjs get-issue "$ISSUE_NUMBER")
ISSUE_TITLE=$(node -e "console.log(JSON.parse(process.argv[1]).title)" "$ISSUE_JSON")
ISSUE_BODY=$(node -e "console.log(JSON.parse(process.argv[1]).body ?? '')" "$ISSUE_JSON")

# A run that dies before commenting would leave the issue silent.
COMMENT_POSTED=""
cleanup() {
  code=$?
  if [ "$code" -ne 0 ] && [ -z "$COMMENT_POSTED" ]; then
    node scripts/agent/gh.mjs comment "$ISSUE_NUMBER" "## 🤖 Agent fix

⚠️ **No PR opened** — the fix agent errored or its change did not pass \`tsc\`; see the agent-fix run logs on EAS. Comment \`@expo-bot <hint>\` here to retry with guidance.

_Posted by the agent-fix EAS workflow._" || true
  fi
}
trap cleanup EXIT

git config user.name "expo-bot"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout -b "$BRANCH"

cat > /tmp/fix-prompt.md <<EOF_PROMPT
You are resolving a GitHub issue in this Expo React Native app
(PickPulse, a sports picks demo app). The issue may be a bug report or
a small feature/UX request.

GitHub issue #${ISSUE_NUMBER}: ${ISSUE_TITLE}

${ISSUE_BODY}

Instructions:
1. Understand what the issue asks for. Start with src/lib and src/app.
   The app uses expo-router; navigation lives in src/app/_layout.tsx.
2. Implement a minimal, correct fix. Do not refactor unrelated code.
3. Run: npx tsc --noEmit — and make sure it passes.
4. Do NOT commit or push. Just edit the files.
EOF_PROMPT
if [ -n "$INSTRUCTION" ]; then
  printf '\nGuidance from the person who triggered this run (binding): %s\n' "$INSTRUCTION" >> /tmp/fix-prompt.md
fi

timeout 10m claude -p "$(cat /tmp/fix-prompt.md)" \
  --permission-mode acceptEdits \
  --max-turns 80 \
  --output-format stream-json --verbose \
  --allowedTools "Read Glob Grep Edit Write Bash(npx tsc*) Bash(node*)" \
  | node .eas/gate-log-format.js || true

# Hard gate: never push code that does not type-check.
npx tsc --noEmit

git add -A
if git diff --cached --quiet; then
  node scripts/agent/gh.mjs comment "$ISSUE_NUMBER" "## 🤖 Agent fix

⚠️ **No PR opened** — the agent made no change for this issue. Comment \`@expo-bot <hint>\` here with more detail to retry.

_Posted by the agent-fix EAS workflow._"
  COMMENT_POSTED=1
  exit 0
fi
git commit -m "fix: resolve issue #${ISSUE_NUMBER} - ${ISSUE_TITLE}"

REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git"
git push --force "$REMOTE" "HEAD:${BRANCH}"

# Same shape as every bot post: "## 🤖 <stage>", bold label lines, then
# what lands on the PR next.
PR_BODY="## 🤖 Automated fix for #${ISSUE_NUMBER}

**Issue:** #${ISSUE_NUMBER} ${ISSUE_TITLE}
**How:** Claude Code read the issue, implemented a fix, and \`tsc\` passes

**Posted below as they complete:** code review · agent verification on an EAS cloud simulator with screenshot evidence · this PR's own \`pr-<number>\` update channel to surf to from the app's ⚙︎ Preview Channel screen.

Comment \`@expo-bot <change>\` on this PR to iterate, \`@expo-bot preview\` for a simulator in your browser, or \`@expo-bot qa\` for a generated Maestro test.

Closes #${ISSUE_NUMBER}. _Opened by the agent-fix EAS workflow._"

PR_JSON=$(node scripts/agent/gh.mjs create-pr "$BRANCH" \
  "Fix: ${ISSUE_TITLE} (#${ISSUE_NUMBER})" \
  "$PR_BODY")
PR_URL=$(node -e "console.log(JSON.parse(process.argv[1]).url)" "$PR_JSON")
echo "Opened fix PR: $PR_URL"

node scripts/agent/gh.mjs comment "$ISSUE_NUMBER" "## 🤖 Agent fix

**Status:** ✅ Fix PR opened — ${PR_URL}

Code review, a cloud-simulator verification with screenshot evidence, and the PR's own update channel land on the PR as they complete.

_Posted by the agent-fix EAS workflow._"
COMMENT_POSTED=1
