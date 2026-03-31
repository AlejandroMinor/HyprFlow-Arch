#!/bin/bash
# Uso: ./peripherals_battery.sh mouse | keyboard | magic-trackpad

TYPE=$1

ICON_MOUSE="󰍽"
ICON_KBD="󰌌"
ICON_TRACKPAD="󰟸"
ICON_GENERIC="󰍽"

if [ "$TYPE" == "mouse" ]; then
    KEYWORDS=("Master" "Mouse" "Anywhere")
    ICON=$ICON_MOUSE
elif [ "$TYPE" == "keyboard" ]; then
    KEYWORDS=("Keys" "Keyboard")
    ICON=$ICON_KBD
elif [ "$TYPE" == "magic-trackpad" ]; then
    KEYWORDS=("Magic Trackpad")
    ICON=$ICON_TRACKPAD
else
    KEYWORDS=("hidpp")
    ICON=$ICON_GENERIC
fi

DEV_PATH=""
FINAL_MODEL=""

for path in $(upower -e); do
    MODEL_NAME=$(upower -i "$path" | grep "model:" | cut -d':' -f2 | xargs)
    
    for key in "${KEYWORDS[@]}"; do
        if [[ "$MODEL_NAME" == *"$key"* ]]; then
            DEV_PATH=$path
            FINAL_MODEL=$MODEL_NAME
            break 2
        fi
    done
done

if [ -z "$DEV_PATH" ]; then
    echo '{"text": "", "class": "not-found"}'
    exit 0
fi

INFO=$(upower -i "$DEV_PATH")
PERCENT=$(echo "$INFO" | grep "percentage:" | awk '{print $2}' | tr -d '%')
STATE=$(echo "$INFO" | grep "state:" | awk '{print $2}')

if [ -z "$PERCENT" ]; then
    echo '{"text": "", "class": "no-data"}'
    exit 0
fi

CLASS="fine"
if [ "$PERCENT" -le 20 ]; then
    CLASS="critical"
elif [ "$PERCENT" -le 35 ]; then
    CLASS="warning"
fi

DISPLAY_ICON=$ICON
if [[ "$STATE" == "charging" ]]; then
    DISPLAY_ICON="󱐋$ICON"
fi

TOOLTIP="${FINAL_MODEL}\\nEstado: ${STATE}\\nBatería: ${PERCENT}%"

printf '{"text": "%s %d%%", "tooltip": "%s", "class": "%s"}\n' \
    "$DISPLAY_ICON" "$PERCENT" "$TOOLTIP" "$CLASS"