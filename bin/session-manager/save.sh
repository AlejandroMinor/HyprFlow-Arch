#!/bin/bash

source ~/.cache/wallust/colors/colors-rofi-sh.conf

MODE=$1
SCRIPT_DIR="$HOME/.local/bin/session-manager"

if [ "$MODE" == "logout" ]; then
    python3 "$SCRIPT_DIR/snapshot.py" default
    
    notify-send "Hyprland" "Sesión guardada. Cerrando sesión..." -u critical -t 1500

    sleep 0.5
    
    hyprctl dispatch exit
    exit 0
fi

if [ "$MODE" == "custom" ]; then
    NAME=$(rofi -dmenu \
        -p "  Nombre:" \
        -theme $HOME/.config/rofi/launchers/type-2/style-1_simple.rasi \
        -theme-str "window { width: 400px; location: center; anchor: center; x-offset: 0px; y-offset: 0px; } listview { lines: 0; } element selected.normal { border: 0px 0px 0px 4px; border-color: ${color2}; background-color: ${color0}; }")
    
    if [ -z "$NAME" ]; then
        exit 0
    fi
    
    SAFE_NAME="${NAME// /-}"
    
    python3 "$SCRIPT_DIR/snapshot.py" "$SAFE_NAME"
    notify-send "Workflows" "Plantilla '$SAFE_NAME' guardada correctamente." -t 2000
fi