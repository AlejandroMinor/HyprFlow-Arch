#!/usr/bin/env bash
# Brightness keys: change the panel backlight, then show where it ended up on
# the Quickshell OSD (a notification when it is not running).
#
#   brightness.sh up | down

set -uo pipefail

# shellcheck source=common.sh
. "$(dirname "$(readlink -f "$0")")/common.sh"
hyprflow_name $'\U000F00DF' brightness 33 Brightness

command -v brightnessctl >/dev/null 2>&1 || exit 0

STEP=10
case "${1:-}" in
    up)   glyph=$'\U000F00E0' ; brightnessctl set "${STEP}%+" >/dev/null ;;  # brighter
    down) glyph=$'\U000F00DD' ; brightnessctl set "${STEP}%-" >/dev/null ;;  # dimmer
    *) echo "usage: brightness.sh up|down" >&2; exit 1 ;;
esac

# "intel_backlight,backlight,500,50%,1000": the fourth field is the percentage.
percent=$(brightnessctl -m 2>/dev/null | cut -d, -f4)
[ -n "$percent" ] || exit 0

osd "$glyph" "Brightness" "$percent" "${percent%\%}" || notify "Brightness $percent"
