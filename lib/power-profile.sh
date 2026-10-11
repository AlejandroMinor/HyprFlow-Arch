#!/usr/bin/env bash
# Switches to the next power profile (power-saver, balanced, performance) and
# says which one is on. Profiles this machine lacks are skipped: performance
# needs hardware support. Super+K runs it.

# shellcheck source=common.sh
. "$(dirname "$(readlink -f "$0")")/common.sh"

command -v powerprofilesctl >/dev/null 2>&1 || exit 0

current=$(powerprofilesctl get 2>/dev/null) || exit 0
mapfile -t have < <(powerprofilesctl list 2>/dev/null | sed -n 's/^[* ] *\([a-z-]*\):$/\1/p')

order=()
for p in power-saver balanced performance; do
    [[ " ${have[*]} " == *" $p "* ]] && order+=("$p")
done
[ ${#order[@]} -gt 1 ] || exit 0

next=${order[0]}
for i in "${!order[@]}"; do
    [ "${order[$i]}" = "$current" ] && next=${order[$(( (i + 1) % ${#order[@]} ))]}
done

powerprofilesctl set "$next" && notify "Power profile: $next"
