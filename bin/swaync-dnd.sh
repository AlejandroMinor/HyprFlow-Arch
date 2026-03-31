#!/bin/bash

dnd_status=$(swaync-client -D)
unread_count=$(swaync-client -c)

icon_normal="🔔"
icon_dnd="🔕"


if [[ "$dnd_status" == "true" ]]; then
    if [[ "$unread_count" -gt 0 ]]; then
        echo "$icon_dnd $unread_count"
    else
        echo "$icon_dnd"
    fi
else
    if [[ "$unread_count" -gt 0 ]]; then
        echo "$icon_normal $unread_count"
    else
        echo "$icon_normal"
    fi
fi
