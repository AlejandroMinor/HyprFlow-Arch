#!/bin/bash
# Closes every window on the active workspace, tiled and floating alike.
# Bound to Super+Shift+Q -- right next to Super+Q (close one window), hence the
# confirmation.
#
# Uses focus-then-close per window: the close dispatcher ignores a window
# argument, it only ever acts on the focused one.

set -uo pipefail

ws="$(hyprctl activeworkspace -j | jq -r '.id')"

mapfile -t addrs < <(
	hyprctl clients -j |
		jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws and .mapped) | .address'
)

count=${#addrs[@]}
((count == 0)) && exit 0

answer=$(printf 'Cancel\nClose %d window(s)' "$count" |
	rofi -dmenu \
		-p "  Close workspace $ws?" \
		-selected-row 0 \
		-theme "$HOME/.config/rofi/hyprflow/list.rasi" \
		-theme-str "window { width: 400px; } listview { lines: 2; }")

[[ "$answer" == Close* ]] || exit 0

# Apps with unsaved work still get to show their own dialog: this is a
# graceful close request, not a kill.
batch=""
for a in "${addrs[@]}"; do
	batch+="dispatch hl.dsp.focus({window = 'address:$a'}) ; dispatch hl.dsp.window.close() ; "
done

hyprctl --batch "$batch" >/dev/null
