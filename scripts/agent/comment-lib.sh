#!/usr/bin/env bash
# Shared pieces of the bot comment shape. Source it; do not run it.
#   evidence_tool <cmd> [args...]         -> the eas-simulator-evidence CLI
#   normalize_verdict "<line>" [FALLBACK] -> line 1 of a verdict file, made unambiguous
#   verdict_badge "<verdict line>"        -> the line with a leading status emoji
#   evidence_thumbs <dir> <site_url>      -> an HTML row of screenshot thumbnails
#   bot_instruction "<text>" [keyword]    -> the instruction in an @expo-bot comment
#
# Every bot post shares one layout: "## 🤖 <stage>", a bold Verdict or
# Status line, a short bullet list (PR, evidence, channel), a thumbnail
# row, the full report folded away, and a "_Posted by_" footer.
#
# The verdict grammar, the thumbnails, the evidence site itself, and the
# PR comment shape live in the eas-simulator-evidence package (a
# devDependency). This file keeps the function names the scripts use.

# --no-install: run the copy in node_modules and fail loudly when it is
# missing, instead of fetching a floating version from the registry.
evidence_tool() { npx --no-install eas-simulator-evidence "$@"; }

# Line 1 of a verdict file decides the result, and agents do not always
# write it cleanly ("PASS: FAIL: ..." has been seen). The package collapses
# a chain of leading keywords to the LAST one, turns a PASS line that still
# mentions FAIL into a FAIL, and makes anything else
# "<fallback>: malformed verdict line: ...". <fallback> is $2 (default FAIL).
normalize_verdict() {
  if [ -n "${2:-}" ]; then
    evidence_tool verdict "$1" --fallback "$2"
  else
    evidence_tool verdict "$1"
  fi
}

# The verdict keyword picks the emoji; the evidence site uses the same
# mapping for its badge color.
verdict_badge() { evidence_tool verdict "$1" --badge; }

# Up to four screenshots from <dir>, in capture order, as linked
# thumbnails served by the evidence site (files sit at the site root).
# Prints nothing when there are no images, so callers can drop it in.
evidence_thumbs() { evidence_tool thumbs "$1" "$2" --max 4; }

# A workflow may receive the raw comment body (comment-triggered run) or
# plain text (manual run). Either way: first line only, minus the
# "@expo-bot" prefix and the optional mode keyword, trimmed.
#   bot_instruction "@expo-bot review check the slip"  -> "check the slip"
#   bot_instruction "@expo-bot"                        -> ""
#   bot_instruction "check the slip"                   -> "check the slip"
#   bot_instruction "@expo-bot change the bar" ""     -> "change the bar"
# The keyword only strips as a whole word. "change" is never a keyword: a
# change request is a sentence, and "change the bar to red" must survive.
bot_instruction() {
  # ${2-...}: an explicit "" means "no keyword", only an omitted $2 defaults.
  local keyword="${2-review|qa|preview}"
  printf '%s' "${1:-}" | head -n 1 \
    | sed -E "s/^@expo-bot[[:space:]]*((${keyword})([[:space:]]+|$))?//" \
    | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}
