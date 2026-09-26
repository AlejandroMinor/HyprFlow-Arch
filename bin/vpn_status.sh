#!/bin/bash
# VPN indicator for Waybar (continuous: no interval). Prints the state once,
# then again only when a network interface appears or goes away: openconnect
# and vpnc bring up a tun device when they connect and drop it when they stop.

emit() {
    local out
    if pgrep -x "openconnect" > /dev/null || pgrep -x "vpnc" > /dev/null; then
        out='{"text":"󰒃","class":"vpn-status-active"}'
    else
        out='{"text":"󰒃","class":"vpn-status-warning"}'
    fi
    [ "$out" = "$last" ] && return
    last="$out"
    printf '%s\n' "$out"
}

# Waybar does not stop its continuous modules when it exits, and the loop
# below would outlive it (another copy on every Waybar restart). Watch the
# parent and take this script and its children down with it.
# Waybar starts each module as its own process group, so the whole group
# (this script, its pactl or ip monitor, and this watcher) goes at once. Only
# when the script leads its group, so running it by hand from a terminal never
# signals the terminal's group.
# The check runs now: by the time Waybar is gone it has already killed this
# script, and the group outlives its leader under the same number.
if [ "$(ps -o pgid= -p $$ | tr -d ' ')" = "$$" ]; then
    ( parent=$PPID
      while kill -0 "$parent" 2>/dev/null; do sleep 5; done
      kill -- -$$ 2>/dev/null ) &
fi

last=""
emit
while true; do
    ip -o monitor link 2>/dev/null | while read -r _; do
        emit
    done
    sleep 1
    emit
done
