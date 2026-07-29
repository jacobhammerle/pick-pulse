#!/usr/bin/env bash
# Claude Code reviews the PR diff and posts a review comment.
# Requires: PR_NUMBER, BASE_REF, ANTHROPIC_API_KEY, GITHUB_TOKEN, GH_REPO
set -euo pipefail

git fetch origin "$BASE_REF" --depth 50
git diff "origin/${BASE_REF}"...HEAD > /tmp/pr.diff

PROMPT=$(cat <<EOF
Review this pull request diff for an Expo React Native sports picks
demo app. The diff is in /tmp/pr.diff.

Write a concise code review in GitHub Markdown to /tmp/review.md:
1. One-line summary of what the change does.
2. Correctness: does the change actually fix the stated problem?
   Check edge cases (payout multipliers only exist for 2-6 picks).
3. Any real bugs or risks. Skip style nits.
4. End with a clear verdict line: "✅ LGTM" or "⚠️ Needs changes".

Keep it under 250 words.
EOF
)

claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --allowedTools "Read Write Glob Grep"

REVIEW=$(cat /tmp/review.md)
node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Automated code review

$REVIEW

---
_Posted by the code-review EAS workflow._"
