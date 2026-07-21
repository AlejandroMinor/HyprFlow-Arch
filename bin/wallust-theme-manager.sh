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
    FOCUSED=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name')
    WP_PATH=$(awww query 2>/dev/null | grep "^: ${FOCUSED}:" | grep -oP 'image: \K.*')

    if [ -z "$WP_PATH" ] || [ ! -f "$WP_PATH" ]; then
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

# Rebuild the lockscreen backdrop now rather than on the next lock. Blurring the
# band takes a couple of seconds, so this runs detached and the wallpaper change
# stays instant -- but it waits for the build inside that detached process, so
# the config it writes points at the finished backdrop rather than the raw
# wallpaper.
LOCKSCREEN_GEOMETRY="$HOME_DIR/.config/hypr/hyprlock/geometry.sh"
[ -x "$LOCKSCREEN_GEOMETRY" ] && setsid "$LOCKSCREEN_GEOMETRY" --wait-backdrop >/dev/null 2>&1 &

if [ "$NOTIFY" = true ]; then
    notify-send -i "color-management" "Theme Manager" "Sync complete."
fi