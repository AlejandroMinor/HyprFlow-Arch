#!/bin/bash
# shellcheck disable=SC2154  # color0..15 come from the wallust palette (load_palette)
# help-binds.sh: the Hyprland keybindings in rofi (Super+I).
#
# Reads the descriptions straight from keybindings.lua (via help-binds-parse.py)
# instead of `hyprctl binds -j`: on Hyprland 0.56 that output is invalid JSON
# for every bind registered through the native Lua API (dispatcher "__lua"),
# which is how this whole config binds since the Lua migration.

# shellcheck source=common.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/common.sh"
load_palette

pkill -x rofi && exit 0

THEME="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/hyprflow/list.rasi"
KEYBINDS_LUA="$HYPRFLOW_LIB/../dotconfig/hypr/keybindings.lua"
GESTURES_LUA="$HYPRFLOW_LIB/../dotconfig/hypr/gestures.lua"

python3 "$HYPRFLOW_LIB/help-binds-parse.py" "$KEYBINDS_LUA" "$GESTURES_LUA" | \
awk -F'\t' -v accent="${color15:-#c0caf5}" -v muted="${color8:-#565f89}" '
function esc(s) {
    gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s)
    return s
}
{
    if ($2 == "" || $3 == "") next
    if ($1 != section) {
        section = $1
        printf "<span size=\"small\" color=\"%s\"><b>%s</b></span>\n", muted, esc(section)
    }
    tag = ($4 != "") ? "  <span size=\"x-small\" color=\"" muted "\">[" esc($4) "]</span>" : ""
    printf "    <b><span color=\"%s\">%s</span></b>   %s%s\n", accent, esc($2), esc($3), tag
}' | \
rofi -dmenu \
    -i \
    -markup-rows \
    -p "Keybindings" \
    -theme "$THEME" \
    -theme-str 'window {width: 900px;} listview {lines: 12;}'
