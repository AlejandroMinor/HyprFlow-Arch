#!/usr/bin/env bash
# Picks between the wallpaper palette and the static themes in
# ~/.config/wallust/themes/, which are listed as found: drop a new JSON there
# and it shows up. wallust-theme-manager.sh does the applying.

set -uo pipefail

THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wallust/themes"
HERE="$(dirname "$(readlink -f "$0")")"
MANAGER="$HERE/wallust-theme-manager.sh"
AUTO="Wallpaper (Auto)"
FIRST=(classic nocturne)   # shown right after the wallpaper, the rest A-Z

# accent-blue -> Accent Blue
title() { sed -E 's/-/ /g; s/(^| )([a-z])/\1\u\2/g' <<<"$1"; }

theme_names() {
    local name
    for name in "${FIRST[@]}"; do
        [ -f "$THEMES_DIR/$name.json" ] && printf '%s\n' "$name"
    done
    for name in "$THEMES_DIR"/*.json; do
        name="$(basename "$name" .json)"
        [[ " ${FIRST[*]} " == *" $name "* ]] || printf '%s\n' "$name"
    done
}

main() {
    local selected name
    selected="$( { printf '%s\n' "$AUTO"; theme_names | while read -r name; do title "$name"; done; } \
        | fzf --prompt="  Pick a theme > " --height=30% --border=rounded \
              --layout=reverse --no-info --color="$("$HERE/../lib/fzf-colors.sh")")"
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
