#!/usr/bin/env bash
#
# Prints battery charge, or nothing without one: geometry.sh emits the label
# only when this produces output.

set -uo pipefail

battery_dir=

for path in /sys/class/power_supply/BAT*; do
    [ -e "$path" ] || continue
    battery_dir=$path
    break
done

[ -n "$battery_dir" ] || exit 0

if ! read -r charge <"$battery_dir/capacity" 2>/dev/null; then
    exit 0
fi

case $charge in
    ''|*[!0-9]*) exit 0 ;;
esac

state=Unknown
read -r state <"$battery_dir/status" 2>/dev/null || true

if [ "$state" = "Charging" ]; then
    icon="󰂄"
elif [ "$charge" -ge 90 ]; then
    icon="󰁹"
elif [ "$charge" -ge 70 ]; then
    icon="󰂀"
elif [ "$charge" -ge 50 ]; then
    icon="󰁾"
elif [ "$charge" -ge 30 ]; then
    icon="󰁼"
elif [ "$charge" -ge 15 ]; then
    icon="󰁺"
else
    icon="󰂃"
fi

printf '%s %s%%\n' "$icon" "$charge"
