#!/bin/bash

TEMPLATE_NAME="${1:-default}"
TEMPLATE_FILE="$HOME/.config/hypr/templates/${TEMPLATE_NAME}.json"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Error: Layout '$TEMPLATE_NAME' not found."
    exit 1
fi

echo "🚀 Loading layout: $TEMPLATE_NAME"

jq -c '.[]' "$TEMPLATE_FILE" | while read -r i; do
    WS=$(echo "$i" | jq -r '.workspace')
    CMD=$(echo "$i" | jq -r '.command')
    INIT_CLASS=$(echo "$i" | jq -r '.initialClass')
    FLOATING=$(echo "$i" | jq -r '.floating')
    POS_X=$(echo "$i" | jq -r '.at[0]')
    POS_Y=$(echo "$i" | jq -r '.at[1]')
    SIZE_W=$(echo "$i" | jq -r '.size[0]')
    SIZE_H=$(echo "$i" | jq -r '.size[1]')

    if [ "$WS" -lt 0 ]; then
        WS_TARGET="special:magic"
    else
        WS_TARGET="$WS"
    fi

    BEFORE_ADDRS=$(hyprctl clients -j | jq -r --arg ic "$INIT_CLASS" \
        '.[] | select(.initialClass == $ic) | .address' | tr '\n' ',')

    setsid nohup bash -c "$CMD" >/dev/null 2>&1 &

    NEW_ADDR=""
    for attempt in $(seq 1 10); do
        sleep 0.5
        NEW_ADDR=$(hyprctl clients -j | jq -r --arg ic "$INIT_CLASS" \
            '.[] | select(.initialClass == $ic) | .address' | while read addr; do
                if [[ ",$BEFORE_ADDRS," != *",$addr,"* ]]; then
                    echo "$addr"
                fi
            done | tail -1)
        if [ -n "$NEW_ADDR" ]; then
            hyprctl dispatch "hl.dsp.window.move({workspace='$WS_TARGET', follow=false, window='address:$NEW_ADDR'})"

            if [ "$FLOATING" = "true" ]; then
                hyprctl dispatch "hl.dsp.window.float({action='enable', window='address:$NEW_ADDR'})"
                hyprctl dispatch "hl.dsp.window.move({x=$POS_X, y=$POS_Y, window='address:$NEW_ADDR'})"
                hyprctl dispatch "hl.dsp.window.resize({x=$SIZE_W, y=$SIZE_H, window='address:$NEW_ADDR'})"
            fi

            echo "✅ $INIT_CLASS → $WS_TARGET ($NEW_ADDR) floating=$FLOATING"
            break
        fi
    done

    if [ -z "$NEW_ADDR" ]; then
        echo "⚠️  Timeout waiting for $INIT_CLASS window"
    fi
done
