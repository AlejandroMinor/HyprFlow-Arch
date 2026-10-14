#!/usr/bin/env bash
# screenshot.sh: take a screenshot, annotate it in satty, and say where it went.
# The keybindings.lua screenshot submap calls it after leaving the submap.
#
#   screenshot.sh region|window|output [--clipboard]
#   screenshot.sh _copy PREVIEW  satty's copy command: clipboard + preview
#
# A saved shot becomes a notification with a preview and the file path, which
# the "Open" button hands to xdg-open. --clipboard, or a copy from satty, says
# "Copied to clipboard" with a preview instead.

set -uo pipefail

# shellcheck source=common.sh
. "$(dirname "$(readlink -f "$0")")/common.sh"
hyprflow_name $'\U000F0100' screenshot 36 Screenshot

# satty copies through here, so a copy from satty leaves a preview behind.
if [ "${1:-}" = "_copy" ]; then
    tee "$2" | wl-copy --type image/png
    exit 0
fi

# One preview per shot, so an older toast keeps its image; a day later it goes.
runtime="${XDG_RUNTIME_DIR:-/tmp}"
find "$runtime" -maxdepth 1 -name 'hyprflow-shot-*.png' -mmin +1440 -delete 2>/dev/null
preview="$runtime/hyprflow-shot-$(date +%s%N).png"

copied() {
    notify --icon camera-photo-symbolic --timeout 3000 "<img src=\"file://$preview\">Copied to clipboard"
}

mode="${1:-region}"
clipboard=0
[ "${2:-}" = "--clipboard" ] && clipboard=1

# Clipboard: the raw shot copied by us, not hyprshot's --clipboard-only, which
# returns before its copy is done. Nothing captured: cancelled.
if [ "$clipboard" = 1 ]; then
    hyprshot -m "$mode" --freeze --raw >"$preview"
    [ -s "$preview" ] || exit 0
    wl-copy --type image/png <"$preview"
    copied
    exit 0
fi

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
out="$dir/$(date '+%Y-%m-%d_%H-%M-%S').png"

# satty prints "File saved to '<path>'." on stderr for the direct save (Ctrl+S,
# into $out) and for "Save as" (a path the user picked), so keep its stderr and
# trust it over $out to report the shot that actually landed on disk.
log=$(mktemp)
trap 'rm -f "$log"' EXIT
hyprshot -m "$mode" --freeze --raw \
    | satty --copy-command "$(readlink -f "$0") _copy $preview" --early-exit all --action-on-enter save-to-file \
            --right-click-copy --filename - --output-filename "$out" \
            --disable-notifications 2>"$log"
saved=$(sed -n "s/.*File saved to '\([^']*\)'.*/\1/p" "$log" | tail -n1)
[ -n "$saved" ] && out="$saved"

# No file: copied in satty (a preview was left), or cancelled.
if [ ! -f "$out" ]; then
    [ -s "$preview" ] && copied
    exit 0
fi

# The <img> makes the shot its own small preview at the bottom of the toast;
# the path after it stays as text and is what "Open" (xdg-open) uses.
notify --icon camera-photo-symbolic --timeout 8000 --action open=Open "<img src=\"file://$out\">$out"
