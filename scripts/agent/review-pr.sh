#!/usr/bin/env bash
# Claude Code reviews the PR diff and posts a review comment.
# Requires: PR_NUMBER, BASE_REF, ANTHROPIC_API_KEY, GITHUB_TOKEN, GH_REPO
set -euo pipefail

# The EAS checkout is shallow (depth 1), so HEAD has no recorded parents and
# a three-dot diff may find no merge base. Deepen first, then fetch the base
# branch; FETCH_HEAD is used because a single-branch checkout may not create
# an origin/<base> tracking ref. Fall back to a two-dot diff when there is
# still no merge base.
git fetch --deepen 100 origin 2>/dev/null || true
git fetch origin "$BASE_REF" --depth 100
if ! git diff FETCH_HEAD...HEAD > /tmp/pr.diff 2>/dev/null; then
  echo "No merge base in the shallow checkout; using a two-dot diff."
  git diff FETCH_HEAD HEAD > /tmp/pr.diff
fi

PROMPT=$(cat <<EOF
Review this pull request diff for an Expo React Native sports picks
demo app. The diff is in /tmp/pr.diff.

This app ships to iOS only. Do not flag Android or web compatibility
issues (iOS-only APIs, platform-specific rendering, and similar), and
do not base a verdict on them.

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
