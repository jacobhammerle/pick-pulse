#!/usr/bin/env bash
# Runs Claude Code to fix a GitHub issue, then opens a PR.
# Requires: ISSUE_NUMBER, ANTHROPIC_API_KEY, GITHUB_TOKEN, GH_REPO
set -euo pipefail

BRANCH="fix/issue-${ISSUE_NUMBER}"

ISSUE_JSON=$(node scripts/agent/gh.mjs get-issue "$ISSUE_NUMBER")
ISSUE_TITLE=$(node -e "console.log(JSON.parse(process.argv[1]).title)" "$ISSUE_JSON")
ISSUE_BODY=$(node -e "console.log(JSON.parse(process.argv[1]).body ?? '')" "$ISSUE_JSON")

git config user.name "pickpulse-agent"
git config user.email "agent@users.noreply.github.com"
git checkout -b "$BRANCH"

PROMPT=$(cat <<EOF
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
EOF
)

claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read Glob Grep Edit Write Bash(npx tsc*) Bash(node*)"

# Verify the agent left the tree compiling.
npx tsc --noEmit

git add -A
git commit -m "fix: resolve issue #${ISSUE_NUMBER} - ${ISSUE_TITLE}"

REMOTE="https://x-access-token:${GITHUB_TOKEN}@github.com/${GH_REPO}.git"
git push "$REMOTE" "HEAD:${BRANCH}"

PR_BODY="Automated fix for #${ISSUE_NUMBER}.

This PR was produced by the agent-fix EAS workflow. Verification on an
EAS cloud simulator, an EAS Update preview channel, and automated code
review will be posted below.

Closes #${ISSUE_NUMBER}."

node scripts/agent/gh.mjs create-pr "$BRANCH" \
  "Fix: ${ISSUE_TITLE} (#${ISSUE_NUMBER})" \
  "$PR_BODY"
