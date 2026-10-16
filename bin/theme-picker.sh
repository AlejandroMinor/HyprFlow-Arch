#!/usr/bin/env bash
# Picks between the wallpaper palette and the static themes in
# ~/.config/wallust/themes/, which are listed as found: drop a new JSON there
# and it shows up. wallust-theme-manager.sh does the applying.
#
#     theme-picker.sh            the fzf picker, for the terminal or SSH
#     theme-picker.sh --toggle   the Quickshell panel, or the fzf picker
#     theme-picker.sh --json     the list for the panel
#                                ([{name, title, section, colors, current}])
#     theme-picker.sh --set NAME apply NAME, no menu ("auto" for the wallpaper)

set -uo pipefail

# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wallust/themes"
MANAGER="$HYPRFLOW_BIN/wallust-theme-manager.sh"
AUTO="Wallpaper (Auto)"
AUTO_NAME="auto"
FIRST=(classic nocturne)   # shown right after the wallpaper, then accent-*, the rest A-Z
CURRENT_FILE="$HYPRFLOW_STATE/theme"  # written by wallust-theme-manager.sh

# accent-blue -> Accent Blue
title() { sed -E 's/-/ /g; s/(^| )([a-z])/\1\u\2/g' <<<"$1"; }

# The panel's heading for a theme; theme_names keeps each run together.
section() {
    case "$1" in
        "$AUTO_NAME") echo "Wallpaper" ;;
        accent-*)     echo "Accent" ;;
        *)            [[ " ${FIRST[*]} " == *" $1 "* ]] && echo "Base" || echo "Palettes" ;;
    esac
}

theme_names() {
    local name want
    for name in "${FIRST[@]}"; do
        [ -f "$THEMES_DIR/$name.json" ] && printf '%s\n' "$name"
    done
    for want in Accent Palettes; do
        for name in "$THEMES_DIR"/*.json; do
            [ -e "$name" ] || continue  # no themes: the pattern comes back as is
            name="$(basename "$name" .json)"
            [ "$(section "$name")" = "$want" ] && printf '%s\n' "$name"
        done
    done
}

# The swatches a row shows: background, four accents, foreground.
theme_colors() {
    jq -c '[.special.background, .colors.color1, .colors.color2,
            .colors.color4, .colors.color5, .special.foreground] | map(select(. != null))' \
        "$THEMES_DIR/$1.json" 2>/dev/null || echo '[]'
}

# The wallpaper has no file: its swatches are the palette in use, when it is.
auto_colors() {
    local background="" foreground="" color1="" color2="" color4="" color5=""
    load_palette || { echo '[]'; return; }
    printf '%s\n' "$background" "$color1" "$color2" "$color4" "$color5" "$foreground" \
        | jq -R . | jq -sc 'map(select(. != ""))'
}

# One row of the panel's list.
entry() {
    local name="$1" title="$2" colors="$3" current="$4"
    jq -nc --arg name "$name" --arg title "$title" --arg section "$(section "$name")" \
        --argjson colors "$colors" --argjson current "$current" \
        '{name: $name, title: $title, section: $section, colors: $colors, current: $current}'
}

# The list the Quickshell panel draws, in the same order as the fzf menu.
as_json() {
    local current="" name colors
    [ -r "$CURRENT_FILE" ] && read -r current < "$CURRENT_FILE"
    {
        colors='[]'
        [ "$current" = "$AUTO_NAME" ] && colors="$(auto_colors)"
        entry "$AUTO_NAME" "$AUTO" "$colors" "$([ "$current" = "$AUTO_NAME" ] && echo true || echo false)"
        while read -r name; do
            entry "$name" "$(title "$name")" "$(theme_colors "$name")" \
                "$([ "$current" = "$name" ] && echo true || echo false)"
        done < <(theme_names)
    } | jq -sc .
}

# Apply a theme by its raw name; the wallpaper palette when it is "auto".
apply() {
    [ -n "$1" ] || exit 1
    if [ "$1" = "$AUTO_NAME" ] || [ "$1" = "$AUTO" ]; then
        exec "$MANAGER" --generate-palette --notify
    fi
    exec "$MANAGER" --theme "$1" --notify
}

# The Quickshell panel when it is up; the terminal picker otherwise, so a
# Waybar or Super+K click still works without Quickshell.
toggle() {
    if qs -c hyprflow ipc call themepicker toggle 2>/dev/null; then
        exit 0
    fi
    hyprctl dispatch "hl.dsp.exec_cmd(\"[float; size 420 260; center] kitty --class kitty-theme-picker -e $HYPRFLOW_BIN/theme-picker.sh\")"
}

main() {
    case "${1:-}" in
        --json)   as_json; exit 0 ;;
        --set)    apply "${2:-}" ;;
        --toggle) toggle; exit 0 ;;
    esac

    local selected name
    selected="$( { printf '%s\n' "$AUTO"; theme_names | while read -r name; do title "$name"; done; } \
        | fzf --prompt="  Pick a theme > " --height=30% --border=rounded \
              --layout=reverse --no-info --color="$("$HYPRFLOW_LIB/fzf-colors.sh")")"
    [ -z "$selected" ] && exit 0

    if [ "$selected" = "$AUTO" ]; then
        exec "$MANAGER" --generate-palette --notify
    fi
    while read -r name; do
        [ "$(title "$name")" = "$selected" ] && exec "$MANAGER" --theme "$name" --notify
    done < <(theme_names)
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
