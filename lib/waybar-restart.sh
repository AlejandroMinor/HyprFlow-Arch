#!/usr/bin/env bash
# Restarts Waybar, or starts it if it is not running. Every script that needs
# a fresh Waybar calls this, so there is one way to do it:
#
#   - the old one is gone before the new one starts (killall -w), so two never
#     overlap and fight over the bar
#   - one restart at a time, each waiting until its Waybar is up: two callers
#     at once (quick wallpaper changes) otherwise both found nothing to kill
#     and both started one, leaving two bars
#   - the new one is launched by Hyprland, not by the caller: it inherits
#     neither the caller's terminal (Waybar's logs would scribble over it) nor
#     its environment (a sandbox's GTK_PATH kills Waybar on startup), nor any
#     file descriptor it holds, like monitors.sh's apply lock
#
# Without Hyprland to ask (a TTY, a broken socket) it starts Waybar itself,
# detached and with the sandbox variables stripped.

set -uo pipefail

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/waybar-restart.lock"
flock -w 15 9 || exit 0

timeout 5 killall -w waybar 2>/dev/null || true

if command -v hyprctl >/dev/null 2>&1 &&
    hyprctl dispatch 'hl.dsp.exec_cmd("waybar")' 2>/dev/null | grep -q '^ok'; then
    :
else
    env -u GTK_PATH -u LOCPATH -u GTK_EXE_PREFIX -u GDK_PIXBUF_MODULEDIR \
        -u GDK_PIXBUF_MODULE_FILE -u GIO_MODULE_DIR -u GTK_IM_MODULE_FILE \
        -u GSETTINGS_SCHEMA_DIR -u SNAP -u SNAP_NAME -u SNAP_LIBRARY_PATH \
        setsid waybar >/dev/null 2>&1 < /dev/null 9>&- &
fi

# Hold the lock until the new Waybar exists, so the next restart finds it.
for _ in $(seq 30); do
    pgrep -x waybar >/dev/null && break
    sleep 0.1
done
