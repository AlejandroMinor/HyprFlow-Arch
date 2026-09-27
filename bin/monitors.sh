#!/usr/bin/env bash
# monitors.sh: monitor wizard and profiles for Hyprland and Waybar.
#   list | setup | apply | mirror [on [MONITOR]|off|toggle] | solo [on [MONITOR [MODE]]|off|toggle]
# The logic lives in lib/monitors.py; this keeps the command's name, which
# Hyprland's hotplug hook, game-mode.sh and install.sh call.
exec python3 "$(dirname "$(readlink -f "$0")")/../lib/monitors.py" "$@"
