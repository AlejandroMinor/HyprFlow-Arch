#!/bin/bash
# Mute indicator for the default output, for Waybar (continuous: no interval).
# Prints the state once, then again only when PipeWire reports a change to a
# sink or to the default device, instead of polling every second.

emit() {
    local out device_name wpctl_info
    if wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q "\[MUTED\]"; then
        device_name="Audio Device"
        wpctl_info=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if grep -q "alsa.card_name" <<<"$wpctl_info"; then
            device_name=$(grep "alsa.card_name" <<<"$wpctl_info" | awk -F'"' '{print $2}')
        fi
        out=$(printf '{"text": "󰖁", "class": "muted_active", "tooltip": "%s is muted"}' "$device_name")
    else
        out='{"text": "󰕾", "class": "", "tooltip": "Click to expand audio"}'
    fi
    # Volume changes fire sink events too; print only when the state changes.
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
# pactl subscribe ends if PipeWire restarts; start it again.
while true; do
    pactl subscribe 2>/dev/null | while read -r line; do
        case "$line" in
            *"on sink "*|*"on server"*) emit ;;
        esac
    done
    sleep 1
    emit
done
