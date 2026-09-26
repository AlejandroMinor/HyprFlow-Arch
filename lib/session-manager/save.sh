#!/bin/bash

MODE=$1
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ "$MODE" == "logout" ]; then
    python3 "$SCRIPT_DIR/snapshot.py" default

    notify-send "Hyprland" "Session saved. Logging out..." -u critical -t 1500

    sleep 0.5

    hyprctl dispatch "hl.dsp.exit()"
    exit 0
fi

if [ "$MODE" == "custom" ]; then
    NAME=$(rofi -dmenu \
        -p "  Name:" \
        -theme "$HOME/.config/rofi/hyprflow/list.rasi" \
        -theme-str "window { width: 400px; } listview { lines: 0; }")

    if [ -z "$NAME" ]; then
        exit 0
    fi

    SAFE_NAME="${NAME// /-}"

    python3 "$SCRIPT_DIR/snapshot.py" "$SAFE_NAME"
    notify-send "Workflows" "Layout '$SAFE_NAME' saved." -t 2000
fi
