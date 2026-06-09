#!/bin/bash

[ -f ~/.cache/wallust/colors/colors-rofi-sh.conf ] && source ~/.cache/wallust/colors/colors-rofi-sh.conf

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
    ROFI_COLORS="* { background: ${background}; background-alt: ${color0}; foreground: ${foreground}; selected: ${color2}; active: ${color6}; urgent: ${color1}; }"

    NAME=$(rofi -dmenu \
        -p "  Name:" \
        -theme $HOME/.config/rofi/launchers/type-2/style-1_simple.rasi \
        -theme-str "${ROFI_COLORS} window { width: 400px; location: center; anchor: center; } listview { lines: 0; } element selected.normal { border: 0px 0px 0px 4px; border-color: ${color2}; background-color: ${color0}; }")

    if [ -z "$NAME" ]; then
        exit 0
    fi

    SAFE_NAME="${NAME// /-}"

    python3 "$SCRIPT_DIR/snapshot.py" "$SAFE_NAME"
    notify-send "Workflows" "Layout '$SAFE_NAME' saved." -t 2000
fi
