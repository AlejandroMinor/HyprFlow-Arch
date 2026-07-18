#!/bin/bash
# help-binds.sh — Keybinds de Hyprland en rofi

source ~/.cache/wallust/colors/colors-rofi-sh.conf

pkill -x rofi && exit 0

THEME="$HOME/.config/rofi/hyprflow/list.rasi"

hyprctl binds -j | jq -r '
  def bit($n): ((. / $n) | floor) % 2 == 1;
  [ .[] | select(.description != "") ]
  | sort_by(.submap)
  | .[]
  | (.modmask | [
      (if bit(64) then "SUPER" else empty end),
      (if bit(8)  then "ALT"   else empty end),
      (if bit(4)  then "CTRL"  else empty end),
      (if bit(1)  then "SHIFT" else empty end)
    ] | join(" + ")) as $mods
  | (if $mods == "" then .key else $mods + " + " + .key end)
    + "\t" + .description
    + "\t" + .submap
' | \
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