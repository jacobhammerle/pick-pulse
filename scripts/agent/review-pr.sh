#!/usr/bin/env bash
# Claude Code reviews the PR diff and posts a review comment on the PR.
# The diff comes from the GitHub API, so the script works the same on a
# pull_request run, an "@expo-bot review" comment, and a manual run (the
# EAS checkout is shallow and may lack the merge base either way).
# Requires: PR_NUMBER, GH_REPO, GITHUB_TOKEN, CLAUDE_CODE_OAUTH_TOKEN
# Optional: INSTRUCTION (reviewer guidance; may be the raw @expo-bot comment)
#           HEAD_REPO, BASE_REPO (fork guard; empty when unknown)
set -euo pipefail

# shellcheck disable=SC1091
. scripts/agent/comment-lib.sh

for v in GITHUB_TOKEN GH_REPO CLAUDE_CODE_OAUTH_TOKEN; do
  if [ -z "${!v:-}" ]; then
    echo "$v is not set; add it as an EAS environment variable (production)."
    exit 1
  fi
done

# Public-repo guard: see verify-on-simulator.sh. Only a visible mismatch
# stops the run.
case "${HEAD_REPO:-}${BASE_REPO:-}" in *'${{'*) HEAD_REPO=''; BASE_REPO='' ;; esac
if [ -n "${HEAD_REPO:-}" ] && [ -n "${BASE_REPO:-}" ] && [ "$HEAD_REPO" != "$BASE_REPO" ]; then
  echo "PR head is fork '$HEAD_REPO'; refusing to run agent scripts with secrets."
  exit 1
fi

# A run that dies before commenting would leave the PR silent.
COMMENT_POSTED=""
cleanup() {
  code=$?
  if [ "$code" -ne 0 ] && [ -z "$COMMENT_POSTED" ]; then
    node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Automated code review

⚠️ **Review errored before it could complete** — see the code-review run logs on EAS, then comment \`@expo-bot review\` to retry.

_Posted by the code-review EAS workflow._" || true
  fi
}
trap cleanup EXIT

INSTRUCTION=$(bot_instruction "${INSTRUCTION:-}" review)
rm -f /tmp/review.md

node scripts/agent/gh.mjs get-pr "$PR_NUMBER" > /tmp/pr-info.json
node scripts/agent/gh.mjs get-pr-diff "$PR_NUMBER" > /tmp/pr.diff

# Keep the diff within a sane prompt budget.
if [ "$(wc -c < /tmp/pr.diff)" -gt 150000 ]; then
  head -c 150000 /tmp/pr.diff > /tmp/pr.diff.capped
  printf '\n\n[diff truncated at 150 kB]\n' >> /tmp/pr.diff.capped
  mv /tmp/pr.diff.capped /tmp/pr.diff
fi

PROMPT=$(cat <<'PROMPT_EOF'
Review this pull request diff for an Expo React Native sports picks
demo app (PickPulse). The diff is in /tmp/pr.diff and the PR title and
body are in /tmp/pr-info.json. You may read the project source
(current working directory) for context.

This app ships to iOS only. Do not flag Android or web compatibility
issues (iOS-only APIs, platform-specific rendering, and similar), and
do not base a verdict on them.

Write a concise code review in GitHub Markdown to /tmp/review.md, in
exactly this shape (fill in the angle-bracket parts, keep everything
else verbatim; lines 1-3 stay visible, the rest is folded away):

**Verdict:** ✅ LGTM

**Summary** — <one line: what the change does and whether it is safe>

1. 🎯 **Correctness** — <does the change do what the PR says? Name
   the edge cases you checked; payout multipliers only exist for 2-6
   picks>
2. 🐛 **Bugs and risks** — <real problems found, most severe first,
   or "None found."; skip style nits>

Use "**Verdict:** ⚠️ Needs changes" instead when you find a real
problem. Keep the whole review under 250 words.
PROMPT_EOF
)
if [ -n "$INSTRUCTION" ]; then
  PROMPT="$PROMPT

Reviewer guidance for this review (from the @expo-bot comment; treat
it as the focus of the review): $INSTRUCTION"
fi

# The review file is the contract; Claude's own exit code is not.
timeout 10m claude -p "$PROMPT" \
  --permission-mode acceptEdits \
  --max-turns 40 \
  --output-format stream-json --verbose \
  --allowedTools "Read Write Glob Grep" \
  | node .eas/gate-log-format.js || true

if [ ! -s /tmp/review.md ]; then
  echo "**Verdict:** ⚠️ Review errored: the reviewer produced no output. See the workflow logs." > /tmp/review.md
fi

# Verdict and summary stay visible; the numbered notes fold away.
REVIEW_HEAD=$(head -n 3 /tmp/review.md)
REVIEW_NOTES=$(tail -n +4 /tmp/review.md | sed '/./,$!d')
NOTES_BLOCK=""
if [ -n "$REVIEW_NOTES" ]; then
  NOTES_BLOCK="
<details>
<summary>Review notes</summary>

${REVIEW_NOTES}

</details>
"
fi
node scripts/agent/gh.mjs comment "$PR_NUMBER" "## 🤖 Automated code review

${REVIEW_HEAD}
${NOTES_BLOCK}
_Posted by the code-review EAS workflow._"
COMMENT_POSTED=1
