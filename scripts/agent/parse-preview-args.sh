#!/usr/bin/env bash
# Parses the text after "@expo-bot preview" into the pr-live-preview
# workflow inputs. Prints two lines: duration=<minutes> and
# device=<name or empty>. PickPulse ships to iOS only, so the session is
# always an iOS simulator; "ios" is accepted and ignored.
#
#   @expo-bot preview                         30 min, runner default device
#   @expo-bot preview 45                      45 min (capped at 120)
#   @expo-bot preview iPhone 16 Pro           device "iPhone 16 Pro"
#   @expo-bot preview 45 iPhone 16 Pro        both
#   @expo-bot preview iPhone 16 Pro for 45    both, natural order
#   @expo-bot preview iPad Pro 13-inch 20m    all of it
#
# Rules, in order, per word:
#   - a bare number is the duration while no device word has been read yet;
#     "for N", "Nm", "Nmin", or "N minutes" is the duration anywhere
#     (so the 16 in "iPhone 16 Pro" stays part of the device name)
#   - filler words "ios", "on", "for", "device", "minute(s)", "min(s)" are dropped
#   - every other word joins the device name
#
# Usage: parse-preview-args.sh "<text after preview>"
set -euo pipefail

TEXT="${1:-}"
DEFAULT_DURATION="${PREVIEW_DEFAULT_MINUTES:-30}"

DURATION=""
DEVICE=""
EXPECT_DURATION=""

# Normalize quotes and commas so `preview "iPhone 16 Pro", 45` also works,
# and glue "10 minutes" into "10m" so the number is never read as part of
# a device name that came before it.
TEXT=$(printf '%s' "$TEXT" | tr '",\047' '   ' \
  | sed -E 's/([0-9]+)[[:space:]]+(minutes|minute|mins|min|m)([[:space:]]|$)/\1m\3/g')
# shellcheck disable=SC2206
WORDS=($TEXT)

for w in ${WORDS[@]+"${WORDS[@]}"}; do
  lower=$(printf '%s' "$w" | tr '[:upper:]' '[:lower:]')
  if [ -n "$EXPECT_DURATION" ] && [[ "$lower" =~ ^([0-9]+)(m|min|mins|minute|minutes)?$ ]]; then
    DURATION="${BASH_REMATCH[1]}"; EXPECT_DURATION=""; continue
  fi
  EXPECT_DURATION=""
  case "$lower" in
    for) EXPECT_DURATION=1; continue ;;
    ios|on|device|minute|minutes|min|mins) continue ;;
  esac
  if [[ "$lower" =~ ^([0-9]+)(m|min|mins|minute|minutes)$ ]]; then
    DURATION="${BASH_REMATCH[1]}"; continue
  fi
  if [[ "$lower" =~ ^[0-9]+$ ]] && [ -z "$DEVICE" ]; then
    DURATION="$lower"; continue
  fi
  DEVICE="${DEVICE:+$DEVICE }$w"
done

MAX_DURATION="${PREVIEW_MAX_MINUTES:-120}"
[ -n "$DURATION" ] || DURATION="$DEFAULT_DURATION"
# A zero-minute session is meaningless; treat it as the default. A session
# longer than the cap is clamped: it bills until it stops.
[ "$DURATION" -gt 0 ] 2>/dev/null || DURATION="$DEFAULT_DURATION"
[ "$DURATION" -le "$MAX_DURATION" ] 2>/dev/null || DURATION="$MAX_DURATION"

echo "duration=$DURATION"
echo "device=$DEVICE"
