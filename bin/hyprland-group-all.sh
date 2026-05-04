#!/bin/bash
# Source: https://gitlab.com/FabianUntermoser/dot-files

ws="$(hyprctl activeworkspace -j | jq -r '.id')"

mapfile -t addrs < <(
	hyprctl clients -j |
		jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws) | .address'
)

((${#addrs[@]} < 2)) && exit 0

batch="dispatch focuswindow address:${addrs[0]}; dispatch togglegroup;"

for a in "${addrs[@]:1}"; do
	batch+=" dispatch focuswindow address:$a;"
	batch+=" dispatch moveintogroup l; dispatch moveintogroup r; dispatch moveintogroup u; dispatch moveintogroup d;"
done

hyprctl --batch "$batch"
