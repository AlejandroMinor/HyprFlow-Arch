#!/usr/bin/env bash

THEMES_DIR="$HOME/.config/wallust/themes"
COLORS_DIR="$HOME/.config/wallust/colors"
CACHE_DIR="$HOME/.cache/wallust/colors"
MANAGER="$HOME/.local/bin/wallust-theme-manager.sh"

SELECTED=$(printf '%s\n' \
    "Wallpaper (Auto)" \
    "Minor Default" \
    "Tokyo Night" \
    "Catppuccin Mocha" \
    "Nord" \
    "Gruvbox" \
    "Dracula" \
    "Monochrome" \
    "Synthwave" \
    "Kanagawa" \
    | fzf \
        --prompt="  Selección de tema > " \
        --height=30% \
        --border=rounded \
        --layout=reverse \
        --no-info \
        --color='bg+:#1a1b26,bg:#0f0f0f,hl:#7aa2f7,fg:#c0caf5,hl+:#bb9af7,prompt:#7aa2f7,pointer:#f7768e')

[ -z "$SELECTED" ] && exit 0

apply_theme() {
    local subdir="$1"
    local json="$2"

    cp "$COLORS_DIR/$subdir"/* "$CACHE_DIR/" 2>/dev/null || true
    wallust cs "$THEMES_DIR/$json"
    hyprctl reload > /dev/null
    killall -SIGUSR2 waybar 2>/dev/null
    notify-send -i "color-management" "Theme Picker" "Tema '$SELECTED' aplicado."
}

case "$SELECTED" in
    "Wallpaper (Auto)")
        "$MANAGER" --generate-palette --notify
        ;;
    "Minor Default")
        apply_theme "." "minor-default.json"
        ;;
    "Tokyo Night")
        apply_theme "tokyo-night" "tokyo-night.json"
        ;;
    "Catppuccin Mocha")
        apply_theme "catppuccin" "catppuccin.json"
        ;;
    "Nord")
        apply_theme "nord" "nord.json"
        ;;
    "Gruvbox")
        apply_theme "gruvbox" "gruvbox.json"
        ;;
    "Dracula")
        apply_theme "dracula" "dracula.json"
        ;;
    "Monochrome")
        apply_theme "monochrome" "monochrome.json"
        ;;
    "Synthwave")
        apply_theme "synthwave" "synthwave.json"
        ;;
    "Kanagawa")
        apply_theme "kanagawa" "kanagawa.json"
        ;;
esac
