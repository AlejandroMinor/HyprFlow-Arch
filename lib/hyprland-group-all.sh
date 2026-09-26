#!/bin/bash
# Source: https://gitlab.com/FabianUntermoser/dot-files
# Adapted to Hyprland's Lua dispatch syntax (hyprctl dispatch now evaluates
# Lua, e.g. "dispatch hl.dsp.group.toggle()" instead of "dispatch togglegroup").

ws="$(hyprctl activeworkspace -j | jq -r '.id')"

mapfile -t addrs < <(
	hyprctl clients -j |
		jq -r --argjson ws "$ws" '.[] | select(.workspace.id == $ws) | .address'
)

((${#addrs[@]} < 2)) && exit 0

batch="dispatch hl.dsp.focus({window = 'address:${addrs[0]}'}); dispatch hl.dsp.group.toggle();"

for a in "${addrs[@]:1}"; do
	batch+=" dispatch hl.dsp.focus({window = 'address:$a'});"
	batch+=" dispatch hl.dsp.window.move({into_group = 'l'}); dispatch hl.dsp.window.move({into_group = 'r'}); dispatch hl.dsp.window.move({into_group = 'u'}); dispatch hl.dsp.window.move({into_group = 'd'});"
done

hyprctl --batch "$batch"
