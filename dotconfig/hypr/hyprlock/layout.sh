#!/usr/bin/env bash
#
# Prints the active keyboard layout, but only when it is not the default: the
# wrong one breaks password entry silently, yet an always-on badge is noise.
# Also silent when the layout cannot be resolved -- that failure is permanent,
# and a badge stuck on forever is worse.

set -uo pipefail

# Names come from the system xkb table, not a hand-written map, so adding or
# reordering layouts needs no change here.
readonly XKB_RULES=/usr/share/X11/xkb/rules/evdev.lst

command -v hyprctl >/dev/null 2>&1 || exit 0

get_configured_layout_code() {
    hyprctl getoption input:kb_layout -j 2>/dev/null \
        | jq -r '.str // empty' \
        | cut -d, -f1
}

get_active_layout_name() {
    hyprctl devices -j 2>/dev/null \
        | jq -r '.keyboards[] | select(.main) | .active_keymap' \
        | head -n1
}

layout_description_for_code() {
    awk -v code="$1" '
        /^! layout/ { in_layouts = 1; next }
        /^!/        { in_layouts = 0 }
        in_layouts && $1 == code {
            $1 = ""
            sub(/^ +/, "")
            print
            exit
        }
    ' "$XKB_RULES"
}

layout_code_for_description() {
    awk -v name="$1" '
        /^! layout/ { in_layouts = 1; next }
        /^!/        { in_layouts = 0 }
        in_layouts {
            code = $1
            $1 = ""
            sub(/^ +/, "")
            if ($0 == name) {
                print code
                exit
            }
        }
    ' "$XKB_RULES"
}

configured_code=$(get_configured_layout_code)
[ -n "$configured_code" ] || exit 0

active_name=$(get_active_layout_name)
[ -n "$active_name" ] || exit 0

default_name=$(layout_description_for_code "$configured_code")
[ -n "$default_name" ] || exit 0

[ "$active_name" = "$default_name" ] && exit 0

active_code=$(layout_code_for_description "$active_name")
[ -n "$active_code" ] || active_code="$active_name"

printf '󰌌  %s\n' "$(printf '%s' "$active_code" | tr '[:lower:]' '[:upper:]')"
