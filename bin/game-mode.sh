#!/usr/bin/env bash
# game-mode.sh: couch gaming on the TV (or any screen), driven by the controller.
#
#   game-mode.sh on [SCREEN] [--keep] | off | toggle [SCREEN] [--keep] | status
#   game-mode.sh bigpicture-closed   (hyprland.lua: leave when Big Picture closes)
#
# On: only the game screen stays on, the rest are switched off; animations,
# blur and shadows go off, VRR turns on for fullscreen games, notifications
# are silenced, Waybar hides, the case lighting goes dark, the sound moves to
# the screen's own audio output (the TV's HDMI) and Steam Big Picture opens.
# Off: puts everything back.
#
# SCREEN overrides the configured one for this time: a port (HDMI-A-1) or part
# of the description (FireTV, NZXT), as `monitors.sh list` shows them.
# --keep leaves the other screens on this time, e.g. for Discord on a side
# monitor.
#
# Per machine settings live outside the repo, in ~/.config/hypr/game-mode.conf:
#
#   GAME_DISPLAY=("FireTV" "NZXT")  # screens in order of preference, the first
#                                   # connected wins; port or part of the
#                                   # description; empty = the largest one
#   GAME_MODE=""             # e.g. 3840x2160@120; empty = the profile's mode
#   GAME_VRR=1               # 1: variable refresh in fullscreen | 0: leave it off
#   GAME_STEAM=1             # 1: open Big Picture | 0: do not touch Steam
#   GAME_RGB=1               # 1: case lighting off (rgb-sync.sh) | 0: leave it
#   GAME_AUDIO=1             # 1: sound to the game screen's output, if it has one | 0: leave it
#
# Works over SSH too: it finds the running Hyprland session by itself.

set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
CONF="$CFG/hypr/game-mode.conf"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hyprflow"
STATE="$STATE_DIR/game-mode"
MONITORS="$(dirname "$(readlink -f "$0")")/monitors.sh"

GAME_DISPLAY=""
GAME_MODE=""
GAME_VRR=1
GAME_STEAM=1
GAME_RGB=1
GAME_AUDIO=1
# shellcheck source=/dev/null
[ -f "$CONF" ] && . "$CONF"

msg()  { printf '\033[1;35m󰊴 game-mode:\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m󰊴 game-mode:\033[0m %s\n' "$*" >&2; }

# An SSH login has none of the session's environment. Point at the newest
# running Hyprland instance and at the session bus (swaync talks over D-Bus).
# `hyprctl instances` lists only live ones: a crashed or logged out session
# leaves its folder behind in $XDG_RUNTIME_DIR/hypr.
attach_session() {
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        local newest
        newest="$(hyprctl instances -j 2>/dev/null | jq -r 'max_by(.time).instance // empty' 2>/dev/null)"
        if [ -n "$newest" ]; then
            HYPRLAND_INSTANCE_SIGNATURE="$newest"
            export HYPRLAND_INSTANCE_SIGNATURE
        fi
    fi
    hyprctl version >/dev/null 2>&1 || { warn "no running Hyprland session found"; exit 1; }
}

# Launches through Hyprland rather than from this shell, so the program shows
# up on the session's screens and survives an SSH logout.
spawn() {
    local cmd="${1//\\/\\\\}"
    cmd="${cmd//\"/\\\"}"
    hyprctl eval "hl.dispatch(hl.dsp.exec_cmd(\"$cmd\"))" >/dev/null
}

# Prints the description of the first connected screen among the candidates
# (arguments), matched by port or by a case-insensitive piece of the
# description. Without candidates, the largest enabled screen.
game_display() {
    local monitors candidate found
    monitors="$(hyprctl monitors all -j)"
    if [ $# -eq 0 ]; then
        jq -r 'map(select(.disabled | not)) | max_by(.width * .height) | .description' <<<"$monitors"
        return
    fi
    for candidate in "$@"; do
        [ -z "$candidate" ] && continue
        found="$(jq -r --arg s "$candidate" '.[]
            | select(.name == $s or (.description | ascii_downcase | contains($s | ascii_downcase)))
            | .description' <<<"$monitors" | head -n1)"
        [ -n "$found" ] && { printf '%s\n' "$found"; return; }
    done
}

is_on() { [ -f "$STATE" ]; }

# The PipeWire sink of a screen, found by the name its HDMI/DP audio carries
# (node.nick "FireTV" for "AMZ FireTV"). Screens without speakers have none.
screen_sink() {
    pactl -f json list sinks 2>/dev/null | jq -r --arg d "$1" '.[]
        | (.properties["node.nick"] // "") as $n
        | select($n != "" and ($d | ascii_downcase | contains($n | ascii_downcase)))
        | .name' | head -n1
}

# Detached: talking to the OpenRGB server takes a second or so.
rgb_sync() {
    local bin; bin="$(dirname "$(readlink -f "$0")")/rgb-sync.sh"
    [ -x "$bin" ] && setsid "$bin" "$@" >/dev/null 2>&1 < /dev/null &
}

# on [SCREEN] [--keep], in any order.
cmd_on() {
    is_on && { msg "already on"; return 0; }
    local display solo=0 dnd candidates=() screen="" keep=0 arg
    for arg in "$@"; do
        case "$arg" in
            --keep) keep=1 ;;
            -*)     warn "unknown option: $arg"; exit 1 ;;
            *)      screen="$arg" ;;
        esac
    done
    # A screen named on the command line beats the configured list.
    if [ -n "$screen" ]; then candidates=("$screen")
    else candidates=("${GAME_DISPLAY[@]}"); fi
    [ "${#candidates[@]}" -eq 1 ] && [ -z "${candidates[0]}" ] && candidates=()
    display="$(game_display "${candidates[@]}")"
    [ -z "$display" ] && { warn "none of these screens is connected: ${candidates[*]}"; exit 1; }

    dnd="$(swaync-client -D 2>/dev/null || echo false)"
    local vrr=0
    [ "$GAME_VRR" = "1" ] && vrr=2  # 2 = fullscreen only; always-on flickers on the desktop

    # The state file is what hyprland.lua reads to keep the game settings on
    # every reload, and what tells monitors.sh to leave Waybar hidden. Written
    # first, so the reload solo triggers already picks it up.
    mkdir -p "$STATE_DIR"
    # Whether Steam was already open, so off can leave it as it found it.
    local steam_was=0
    pgrep -x steam >/dev/null && steam_was=1
    printf 'solo=0\ndnd=%s\nvrr=%s\nsteam_was=%s\n' "$dnd" "$vrr" "$steam_was" > "$STATE"

    if [ "$keep" -eq 0 ]; then
        # shellcheck disable=SC2086
        if ! "$MONITORS" solo on "$display" $GAME_MODE; then
            rm -f "$STATE"
            warn "could not switch to $display"; exit 1
        fi
        solo=1
        sed -i 's/^solo=0/solo=1/' "$STATE"
    fi
    hyprctl reload >/dev/null

    if [ "$GAME_AUDIO" = "1" ]; then
        local sink prev
        sink="$(screen_sink "$display")"
        prev="$(pactl get-default-sink 2>/dev/null)"
        if [ -n "$sink" ] && [ "$sink" != "$prev" ]; then
            pactl set-default-sink "$sink" && printf 'sink_prev=%q\n' "$prev" >> "$STATE"
        fi
    fi

    swaync-client -dn >/dev/null 2>&1 || true
    pkill -x waybar 2>/dev/null || true
    # rgb-sync.sh does nothing without OpenRGB; --last on the way out restores it.
    [ "$GAME_RGB" = "1" ] && rgb_sync --off

    # Steam opens on the focused monitor; with the other screens still on
    # (keep), that could be any of them.
    local port
    port="$(hyprctl monitors -j | jq -r --arg d "$display" '.[] | select(.description == $d) | .name')"
    [ -n "$port" ] && hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$port\" }))" >/dev/null

    if [ "$GAME_STEAM" = "1" ]; then
        # A running Steam takes the URL; a stopped one starts straight in Big Picture.
        if pgrep -x steam >/dev/null; then spawn "steam steam://open/bigpicture"
        else spawn "steam -gamepadui"; fi
    fi

    if [ "$keep" -eq 1 ]; then msg "on: $display (other screens kept on)"
    else msg "on: $display"; fi
}

cmd_off() {
    is_on || { msg "already off"; return 0; }
    local solo=0 dnd=false vrr=0 sink_prev="" steam_was=1
    # shellcheck source=/dev/null
    . "$STATE"
    rm -f "$STATE"

    # Steam goes back to how it was: closed if game mode opened it, else just
    # out of Big Picture. Explicit, rather than relying on Steam quitting by
    # itself when a -gamepadui start leaves Big Picture.
    if [ "$GAME_STEAM" = "1" ] && pgrep -x steam >/dev/null; then
        if [ "$steam_was" = "0" ]; then spawn "steam -shutdown"
        else spawn "steam steam://close/bigpicture"; fi
    fi

    # Without the state file the reload brings the normal settings back.
    if [ "$solo" = "1" ]; then
        "$MONITORS" solo off || warn "could not restore the monitor layout"
    fi
    hyprctl reload >/dev/null

    [ "$dnd" = "true" ] || swaync-client -df >/dev/null 2>&1 || true
    [ "$GAME_RGB" = "1" ] && rgb_sync --last
    [ -n "$sink_prev" ] && pactl set-default-sink "$sink_prev" 2>/dev/null
    pgrep -x waybar >/dev/null || "$(dirname "$(readlink -f "$0")")/../lib/waybar-restart.sh"

    msg "off"
}

attach_session
case "${1:-toggle}" in
    on)     shift; cmd_on "$@" ;;
    off)    cmd_off ;;
    toggle) shift; if is_on; then cmd_off; else cmd_on "$@"; fi ;;
    status) if is_on; then echo on; else echo off; fi ;;
    # Steam closes and reopens the Big Picture window on its own at times (on
    # start, on a resolution change), so only leave if none is back shortly.
    bigpicture-closed)
        sleep 2
        is_on && ! hyprctl clients -j | jq -e 'any(.[]; .title == "Steam Big Picture Mode")' >/dev/null \
            && cmd_off ;;
    *)      warn "usage: game-mode.sh [on [SCREEN] [--keep]|off|toggle [SCREEN] [--keep]|status]"; exit 1 ;;
esac
