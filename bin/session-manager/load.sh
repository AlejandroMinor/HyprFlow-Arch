#!/bin/bash

TEMPLATE_DIR="$HOME/.config/hypr/templates"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

mkdir -p "$TEMPLATE_DIR"

if [ -z "$(ls -A "$TEMPLATE_DIR")" ]; then
    notify-send "Workflows" "No saved layouts found in $TEMPLATE_DIR" -u normal
    exit 1
fi

SELECTION=$(ls "$TEMPLATE_DIR" | sed 's/\.json$//' | rofi -dmenu \
    -p " Layout:" \
    -theme "$HOME/.config/rofi/hyprflow/list.rasi" \
    -theme-str "window { width: 400px; } listview { lines: 3; }")

if [ -n "$SELECTION" ]; then
    bash "$SCRIPT_DIR/restore.sh" "$SELECTION"
    notify-send "Workflows" "Layout '$SELECTION' loaded." -t 2000
fi
