#!/usr/bin/env bash
# Volume keys: change the default output or microphone, then show where it
# ended up. The notification carries a progress bar (swaync's value hint),
# replaces the previous one instead of stacking, and is transient, so it never
# lands in the notification center.
#
#   volume.sh up | down | mute        default output
#   volume.sh mic-mute                default microphone

set -uo pipefail

SINK="@DEFAULT_AUDIO_SINK@"
SOURCE="@DEFAULT_AUDIO_SOURCE@"
STEP="5%"

# percent, then "muted" or nothing, from `wpctl get-volume`.
read_volume() {
    local out
    out="$(wpctl get-volume "$1" 2>/dev/null)" || return 1
    [ -n "$out" ] || return 1
    awk '{ printf "%d", $2 * 100 + 0.5 } /MUTED/ { printf " muted" } END { print "" }' <<<"$out"
}

show() {
    local title="$1" icon="$2" percent="$3" body="$4"
    notify-send -a "Volume" -u low -t 1200 -e -i "$icon" \
        -h string:x-canonical-private-synchronous:volume \
        -h "int:value:$percent" "$title" "$body"
}

case "${1:-}" in
    up)       wpctl set-volume -l 1 "$SINK" "$STEP+" ;;
    down)     wpctl set-volume "$SINK" "$STEP-" ;;
    mute)     wpctl set-mute "$SINK" toggle ;;
    mic-mute) wpctl set-mute "$SOURCE" toggle ;;
    *) echo "usage: volume.sh up|down|mute|mic-mute" >&2; exit 1 ;;
esac

if [ "$1" = mic-mute ]; then
    read -r percent muted < <(read_volume "$SOURCE") || exit 0
    if [ -n "$muted" ]; then
        show "Microphone" microphone-sensitivity-muted-symbolic 0 "Muted"
    else
        show "Microphone" audio-input-microphone-symbolic "$percent" "On  ·  $percent%"
    fi
    exit 0
fi

read -r percent muted < <(read_volume "$SINK") || exit 0
if [ -n "$muted" ]; then
    show "Volume" audio-volume-muted-symbolic 0 "Muted"
elif [ "$percent" -ge 66 ]; then
    show "Volume" audio-volume-high-symbolic "$percent" "$percent%"
elif [ "$percent" -ge 33 ]; then
    show "Volume" audio-volume-medium-symbolic "$percent" "$percent%"
else
    show "Volume" audio-volume-low-symbolic "$percent" "$percent%"
fi
