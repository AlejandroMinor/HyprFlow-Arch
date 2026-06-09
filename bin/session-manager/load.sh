#!/bin/bash

[ -f ~/.cache/wallust/colors/colors-rofi-sh.conf ] && source ~/.cache/wallust/colors/colors-rofi-sh.conf

TEMPLATE_DIR="$HOME/.config/hypr/templates"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

mkdir -p "$TEMPLATE_DIR"

if [ -z "$(ls -A "$TEMPLATE_DIR")" ]; then
    notify-send "Workflows" "No saved layouts found in $TEMPLATE_DIR" -u normal
    exit 1
fi

ROFI_COLORS="* { background: ${background}; background-alt: ${color0}; foreground: ${foreground}; selected: ${color2}; active: ${color6}; urgent: ${color1}; }"

SELECTION=$(ls "$TEMPLATE_DIR" | sed 's/\.json$//' | rofi -dmenu \
    -p " Layout:" \
    -theme $HOME/.config/rofi/launchers/type-2/style-1.rasi \
    -theme-str "${ROFI_COLORS} window { width: 400px; location: center; anchor: center; } listview { lines: 3; columns: 1; } element selected.normal { border: 0px 0px 0px 4px; border-color: ${color2}; background-color: ${color0}; }")

if [ -n "$SELECTION" ]; then
    bash "$SCRIPT_DIR/restore.sh" "$SELECTION"
    notify-send "Workflows" "Layout '$SELECTION' loaded." -t 2000
fi
