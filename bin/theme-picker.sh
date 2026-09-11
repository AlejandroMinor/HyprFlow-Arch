#!/usr/bin/env bash

THEMES_DIR="$HOME/.config/wallust/themes"
COLORS_DIR="$HOME/.config/wallust/colors"
CACHE_DIR="$HOME/.cache/wallust/colors"
MANAGER="$HOME/.local/bin/wallust-theme-manager.sh"

SELECTED=$(printf '%s\n' \
    "Wallpaper (Auto)" \
    "Classic" \
    "Nocturne" \
    "Accent Blue" \
    "Accent Red" \
    "Accent Yellow" \
    "Accent Green" \
    "Accent Purple" \
    "Solarized Dark" \
    "Phosphor Amber" \
    "High Contrast" \
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
    notify-send -i "color-management" "Theme Picker" "Applied theme: $SELECTED"
}

case "$SELECTED" in
    "Wallpaper (Auto)")
        "$MANAGER" --generate-palette --notify
        ;;
    "Classic")
        apply_theme "." "classic.json"
        ;;
    "Nocturne")
        apply_theme "." "nocturne.json"
        ;;
    "Accent Blue")
        apply_theme "." "accent-blue.json"
        ;;
    "Accent Red")
        apply_theme "." "accent-red.json"
        ;;
    "Accent Yellow")
        apply_theme "." "accent-yellow.json"
        ;;
    "Accent Green")
        apply_theme "." "accent-green.json"
        ;;
    "Accent Purple")
        apply_theme "." "accent-purple.json"
        ;;
    "Solarized Dark")
        apply_theme "." "solarized-dark.json"
        ;;
    "Phosphor Amber")
        apply_theme "." "phosphor-amber.json"
        ;;
    "High Contrast")
        apply_theme "." "high-contrast.json"
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
