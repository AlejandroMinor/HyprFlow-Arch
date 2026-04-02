#!/bin/bash

ICON_HEADSET="󰋋"

DATA=$(headsetcontrol -b -o json 2>/dev/null)

CONNECTED=$(echo "$DATA" | jq -r '.device_count // 0')

if [ "$CONNECTED" -eq 0 ]; then
    echo '{"text": "", "class": "not-found"}'
    exit 0
fi

PERCENT=$(echo "$DATA" | jq -r '.devices[0].battery.level')
RAW_STATE=$(echo "$DATA" | jq -r '.devices[0].battery.status')
MODEL_NAME=$(echo "$DATA" | jq -r '.devices[0].product')

if [ "$PERCENT" -le 0 ]; then
    echo '{"text": "", "class": "no-data"}'
    exit 0
fi


DISPLAY_ICON=$ICON_HEADSET
STATE_MSG="Descargando"

if [[ "$RAW_STATE" == "BATTERY_CHARGING" ]]; then
    DISPLAY_ICON="󱐋$ICON_HEADSET"
    STATE_MSG="Cargando"
elif [[ "$RAW_STATE" == "BATTERY_AVAILABLE" ]]; then
    STATE_MSG="En uso"
fi


CLASS="fine"
if [ "$PERCENT" -le 20 ]; then
    CLASS="critical"
elif [ "$PERCENT" -le 35 ]; then
    CLASS="warning"
fi

TOOLTIP="${MODEL_NAME}\\nEstado: ${STATE_MSG}\\nBatería: ${PERCENT}%"

printf '{"text": "%s %d%%", "tooltip": "%s", "class": "%s", "percentage": %d}\n' \
    "$DISPLAY_ICON" "$PERCENT" "$TOOLTIP" "$CLASS" "$PERCENT"


