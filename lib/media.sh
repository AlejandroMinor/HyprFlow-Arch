#!/usr/bin/env bash
# Next and previous with their OSD glyph; the player cannot tell them apart.
# Play/pause is osd-watch.py's. No notification fallback: too noisy.

# shellcheck source=common.sh
. "$(dirname "$(readlink -f "$0")")/common.sh"

case "${1:-}" in
    next)     glyph=$'\U000F04AD'; label="Next" ;;      # md-skip_next
    previous) glyph=$'\U000F04AE'; label="Previous" ;;  # md-skip_previous
    *)        exit 0 ;;
esac

playerctl "$1" 2>/dev/null || exit 0
osd "$glyph" "Media" "$label" -1
