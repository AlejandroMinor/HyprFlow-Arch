#!/usr/bin/env bash
#
# Locks the screen, regenerating geometry for the current monitor setup first.
# Use this instead of calling hyprlock directly, so the layout follows whatever
# displays are attached right now.

set -uo pipefail

pidof hyprlock >/dev/null 2>&1 && exit 0

"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock/geometry.sh" || true

exec hyprlock "$@"
