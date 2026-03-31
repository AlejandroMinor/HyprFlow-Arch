#!/bin/bash
if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q "\[MUTED\]"; then
    wpctl_info=$(wpctl inspect @DEFAULT_AUDIO_SINK@)
    device_name="Audio Device"
    if echo "$wpctl_info" | grep -q "alsa.card_name"; then
        device_name=$(echo "$wpctl_info" | grep "alsa.card_name" | awk -F'"' '{print $2}')
    fi
    printf '{"text": "󰖁", "class": "muted_active", "tooltip": "%s is muted"}\n' "$device_name"
fi