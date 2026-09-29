#!/usr/bin/env bash
#
# Locks the screen, regenerating geometry for the current monitor setup first.
# Use this instead of calling hyprlock directly, so the layout follows whatever
# displays are attached right now.

set -uo pipefail

# Only this user's hyprlock: another session's lock is not this screen's.
pgrep -u "$UID" -x hyprlock >/dev/null 2>&1 && exit 0

geometry="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock/geometry.sh"
[ -x "$geometry" ] && { "$geometry" || true; }

exec hyprlock "$@"
