#!/usr/bin/env bash

ACTION="generate"
SKIP_SEQUENCES=""
NOTIFY=false
DEFAULT_THEME="minor-default"

show_help() {
    echo "Usage: wallust-theme-manager.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --generate-palette   Generate palette from current wallpaper (default)."
    echo "  --restore-default    Restore the static theme (minor-default)."
    echo "  --skip-terminal      Skip injecting colors into active terminals."
    echo "  --notify             Show a notification when done."
    echo "  -h, --help           Show this help."
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --generate-palette) ACTION="generate" ;;
        --restore-default)  ACTION="default" ;;
        --skip-terminal)    SKIP_SEQUENCES="-s" ;;
        --notify)           NOTIFY=true ;;
        -h|--help)          show_help ;;
        *) echo "Error: Unknown argument: $1"; show_help ;;
    esac
    shift
done

HOME_DIR="${HOME:-$(getent passwd "$(whoami)" | cut -d: -f6)}"

WALLUST_CACHE="$HOME_DIR/.cache/wallust/colors"
mkdir -p -m 755 "$WALLUST_CACHE"

if [ "$ACTION" == "generate" ]; then
    WP_PATH=$(sed -n 's/^wallpaper[[:space:]]*=[[:space:]]*//p' "$HOME_DIR/.config/waypaper/config.ini" | sed "s|^~|$HOME_DIR|")

    if [ ! -f "$WP_PATH" ]; then
        [ "$NOTIFY" = true ] && notify-send -u critical "Error" "Wallpaper not found"
        exit 1
    fi

    wallust run $SKIP_SEQUENCES "$WP_PATH"

elif [ "$ACTION" == "default" ]; then
    wallust cs $SKIP_SEQUENCES "$HOME_DIR/.config/wallust/themes/minor-default.json"
    killall -SIGUSR1 kitty 2>/dev/null
fi

hyprctl reload > /dev/null
killall -SIGUSR2 waybar 2>/dev/null

if [ "$NOTIFY" = true ]; then
    notify-send -i "color-management" "Theme Manager" "Sync complete."
fi