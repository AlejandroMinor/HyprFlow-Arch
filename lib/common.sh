# shellcheck shell=bash
# What HyprFlow's shell scripts share, sourced rather than run:
#
#   . "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
#   hyprflow_name "󰍹" monitors 34 Monitors   # icon, name, colour, notification title
#
# That one readlink line is the only path a script works out for itself; the
# rest comes from here: where lib/ and bin/ are, HyprFlow's own folders, the
# wallust palette, and msg/warn/notify with the script's name on them.

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
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    # "--": a message starting with "-" is text, not options.
    notify-send -a "$_hyprflow_app" -- "$_hyprflow_app" "$*" 2>/dev/null || true
}

# Loads the wallust palette (foreground, background, color0..color15) into
# the caller's variables. False when wallust has not written one yet, so the
# caller keeps its own defaults.
load_palette() {
    [ -r "$HYPRFLOW_PALETTE" ] || return 1
    # shellcheck source=/dev/null
    . "$HYPRFLOW_PALETTE"
}
