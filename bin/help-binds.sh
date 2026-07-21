#!/bin/bash
# help-binds.sh — Keybinds de Hyprland en rofi
#
# Lee las descripciones directamente de keybindings.lua (vía help-binds-parse.py)
# en vez de usar `hyprctl binds -j`: en Hyprland 0.56 esa salida es JSON
# inválido para cualquier bind registrado vía la API nativa de Lua
# (dispatcher "__lua"), que es como está todo este config desde la
# migración a Lua.

source ~/.cache/wallust/colors/colors-rofi-sh.conf

pkill -x rofi && exit 0

THEME="$HOME/.config/rofi/hyprflow/list.rasi"
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
KEYBINDS_LUA="$SCRIPT_DIR/../dotconfig/hypr/keybindings.lua"

python3 "$SCRIPT_DIR/help-binds-parse.py" "$KEYBINDS_LUA" | \
awk -F'\t' -v accent="$color15" -v muted="$color8" '
function esc(s) {
    gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s)
    return s
}
{
    if ($1 == "" || $2 == "") next
    tag = ($3 != "") ? "  <span size=\"x-small\" color=\"" muted "\">[" esc($3) "]</span>" : ""
    printf "<b><span color=\"%s\">%s</span></b>   %s%s\n", accent, esc($1), esc($2), tag
}' | \
rofi -dmenu \
    -i \
    -markup-rows \
    -p "Keybindings" \
    -theme "$THEME" \
    -theme-str 'window {width: 900px;} listview {lines: 12;}'
