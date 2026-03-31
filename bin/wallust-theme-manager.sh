#!/usr/bin/env bash

ACTION="generate"
SKIP_SEQUENCES=""
NOTIFY=false
DEFAULT_THEME="minor-default"

show_help() {
    echo "Uso: theme-manager.sh [OPCIONES]"
    echo ""
    echo "Opciones:"
    echo "  --generate-palette   Extrae colores del wallpaper actual (Por defecto)."
    echo "  --restore-default    Restaura el tema estático (minor-default)."
    echo "  --skip-terminal      Evita que wallust inyecte colores en las terminales activas."
    echo "  --notify             Muestra una notificación al terminar."
    echo "  -h, --help           Muestra esta ayuda."
    exit 0
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --generate-palette) ACTION="generate" ;;
        --restore-default)  ACTION="default" ;;
        --skip-terminal)    SKIP_SEQUENCES="-s" ;;
        --notify)           NOTIFY=true ;;
        -h|--help)          show_help ;;
        *) echo "Error: Argumento desconocido: $1"; show_help ;;
    esac
    shift
done

if [ "$ACTION" == "generate" ]; then
    WP_PATH=$(sed -n 's/^wallpaper[[:space:]]*=[[:space:]]*//p' ~/.config/waypaper/config.ini | sed "s|^~|$HOME|")

    if [ ! -f "$WP_PATH" ]; then
        [ "$NOTIFY" = true ] && notify-send -u critical "Error" "No hay wallpaper"
        exit 1
    fi

    wallust run $SKIP_SEQUENCES "$WP_PATH"

elif [ "$ACTION" == "default" ]; then
    wallust cs $SKIP_SEQUENCES "$HOME/.config/wallust/themes/minor-default.json"
    killall -SIGUSR1 kitty 2>/dev/null
fi

hyprctl reload > /dev/null
killall -SIGUSR2 waybar 2>/dev/null

if [ "$NOTIFY" = true ]; then
    notify-send -i "color-management" "Theme Manager" "Sincronización completa."
fi