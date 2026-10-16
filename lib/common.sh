# shellcheck shell=bash
# What HyprFlow's shell scripts share, sourced rather than run:
#
#   . "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
#   hyprflow_name "󰍹" monitors 34 Monitors   # icon, name, colour, notification title
#
# That one readlink line is the only path a script works out for itself; the
# rest comes from here: where lib/ and bin/ are, HyprFlow's own folders, the
# wallust palette, msg/warn/notify with the script's name on them, and the OSD.

# Used by the scripts that source this file.
# shellcheck disable=SC2034
HYPRFLOW_LIB="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
HYPRFLOW_BIN="$(dirname "$HYPRFLOW_LIB")/bin"
HYPRFLOW_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hyprflow"
HYPRFLOW_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hyprflow"
HYPRFLOW_PALETTE="${WALLUST_SH_PALETTE:-${XDG_CACHE_HOME:-$HOME/.cache}/wallust/colors/colors-rofi-sh.conf}"

_hyprflow_icon="" _hyprflow_name="${0##*/}" _hyprflow_colour=36 _hyprflow_app="${0##*/}"

# hyprflow_name ICON NAME [COLOUR [TITLE]]: how msg and warn sign their lines,
# and the title notify gives its notifications (NAME if not given).
hyprflow_name() {
    _hyprflow_icon="$1" _hyprflow_name="$2" _hyprflow_colour="${3:-36}" _hyprflow_app="${4:-$2}"
}

msg()  { printf '\033[1;%sm%s %s:\033[0m %s\n' "$_hyprflow_colour" "$_hyprflow_icon" "$_hyprflow_name" "$*"; }
warn() { printf '\033[1;33m%s %s:\033[0m %s\n' "$_hyprflow_icon" "$_hyprflow_name" "$*" >&2; }

# A desktop notification titled with the script's name; quiet without one.
# Optional flags come first, then the message:
#
#   notify [--urgency U] [--icon I] [--timeout MS] [--transient]
#          [--replace ID] [--category C] [--action KEY=LABEL]... MESSAGE
#
# An action becomes a button in swaync; the command it runs is matched on the
# app name in dotconfig/swaync/config.json, so a notification carries one.
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    local urgency="" icon="" timeout="" actioned=0 extra=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --urgency)  urgency="$2"; shift 2 ;;
            --icon)     icon="$2"; shift 2 ;;
            --timeout)  timeout="$2"; shift 2 ;;
            --transient) extra+=(-e); shift ;;
            --replace)  extra+=(-r "$2"); shift 2 ;;
            --category) extra+=(-c "$2"); shift 2 ;;
            --action)   actioned=1; extra+=(-A "$2"); shift 2 ;;
            *)          break ;;
        esac
    done
    local args=(-a "$_hyprflow_app")
    [ -n "$urgency" ] && args+=(-u "$urgency")
    [ -n "$icon" ] && args+=(-i "$icon")
    [ -n "$timeout" ] && args+=(-t "$timeout")
    args+=("${extra[@]}")
    # "--": a message starting with "-" is text, not options. An action (-A)
    # makes notify-send wait for the user and a critical one never expires, so
    # give it a second to hand the notification over, then move on.
    if [ "$actioned" = 1 ]; then
        timeout 1 notify-send "${args[@]}" -- "$_hyprflow_app" "$*" 2>/dev/null || true
    else
        notify-send "${args[@]}" -- "$_hyprflow_app" "$*" 2>/dev/null || true
    fi
}

# osd ICON TITLE CAPTION VALUE: the level OSD (VALUE < 0: no bar). False
# without Quickshell, so the caller can notify instead.
osd() {
    command -v qs >/dev/null 2>&1 || return 1
    qs -c hyprflow ipc call osd level "$@" 2>/dev/null
}

# A wallust theme's name as people read it: accent-blue -> Accent Blue.
theme_title() { sed -E 's/-/ /g; s/(^| )([a-z])/\1\u\2/g' <<<"$1"; }

# True when Quickshell is running.
quickshell_up() {
    command -v qs >/dev/null 2>&1 || return 1
    qs -c hyprflow ipc show >/dev/null 2>&1
}

# Loads the wallust palette (foreground, background, color0..color15) into
# the caller's variables. False when wallust has not written one yet, so the
# caller keeps its own defaults.
load_palette() {
    [ -r "$HYPRFLOW_PALETTE" ] || return 1
    # shellcheck source=/dev/null
    . "$HYPRFLOW_PALETTE"
}
