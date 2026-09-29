#!/bin/bash
# Sends every monitor to a far-away decoy workspace so the desktop shows up
# clean; a special workspace would work too, but hyprland.lua's
# decoration.blur.special blurs those.

# Per user only: what this file holds ends up in commands for Hyprland, so it
# never lives in a shared /tmp.
[ -n "${XDG_RUNTIME_DIR:-}" ] || { echo "show-desktop: XDG_RUNTIME_DIR is not set" >&2; exit 1; }
STATE_FILE="$XDG_RUNTIME_DIR/hyprland-show-desktop.json"
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

# Only a monitor that exists now and a workspace that is a number make it into
# the dispatch; a stale or damaged state file is dropped instead of sent.
restore_desktop() {
	local batch="" monitor workspace monitors
	monitors="$(hyprctl monitors -j | jq -r '.[].name')"
	while IFS=$'\t' read -r monitor workspace; do
		grep -qxF -- "$monitor" <<<"$monitors" || continue
		[[ $workspace =~ ^-?[0-9]+$ ]] || continue
		batch+="$(dispatch_focus "$monitor" "$workspace")"
	done < <(jq -r '.monitors | to_entries[] | "\(.key)\t\(.value)"' "$STATE_FILE" 2>/dev/null)

	local focused_monitor
	focused_monitor="$(jq -r '.focused_monitor // empty' "$STATE_FILE" 2>/dev/null)"
	grep -qxF -- "$focused_monitor" <<<"$monitors" &&
		batch+="dispatch hl.dsp.focus({monitor = \"$focused_monitor\"});"

	# Kept when the dispatch fails, so the next press can try again.
	if [ -z "$batch" ] || hyprctl --batch "$batch" >/dev/null; then
		rm -f "$STATE_FILE"
	fi
}

if [ -f "$STATE_FILE" ]; then
	restore_desktop
else
	hide_desktop
fi
