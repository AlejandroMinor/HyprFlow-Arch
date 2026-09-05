#!/bin/bash
# Sends every monitor to a far-away decoy workspace so the desktop shows up
# clean; a special workspace would work too, but hyprland.lua's
# decoration.blur.special blurs those.

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprland-show-desktop.json"
FIRST_DECOY_WORKSPACE=901

dispatch_focus() {
	local monitor="$1" workspace="$2"
	echo -n "dispatch hl.dsp.focus({monitor = \"$monitor\"}); dispatch hl.dsp.focus({workspace = $workspace}); "
}

hide_desktop() {
	local focused_monitor
	focused_monitor="$(hyprctl activeworkspace -j | jq -r '.monitor')"

	hyprctl monitors -j | jq --arg fm "$focused_monitor" '{
		monitors: (map({(.name): .activeWorkspace.id}) | add),
		focused_monitor: $fm
	}' >"$STATE_FILE"

	local batch="" monitor decoy=$FIRST_DECOY_WORKSPACE
	while IFS= read -r monitor; do
		batch+="$(dispatch_focus "$monitor" "$decoy")"
		decoy=$((decoy + 1))
	done < <(hyprctl monitors -j | jq -r '.[].name')

	hyprctl --batch "${batch% }"
}

restore_desktop() {
	local batch="" monitor workspace
	while IFS=$'\t' read -r monitor workspace; do
		batch+="$(dispatch_focus "$monitor" "$workspace")"
	done < <(jq -r '.monitors | to_entries[] | "\(.key)\t\(.value)"' "$STATE_FILE")

	local focused_monitor
	focused_monitor="$(jq -r '.focused_monitor' "$STATE_FILE")"
	batch+="dispatch hl.dsp.focus({monitor = \"$focused_monitor\"});"

	hyprctl --batch "$batch"
	rm -f "$STATE_FILE"
}

if [ -f "$STATE_FILE" ]; then
	restore_desktop
else
	hide_desktop
fi
