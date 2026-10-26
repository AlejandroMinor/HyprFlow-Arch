#!/usr/bin/env bash
# Interactive picker for the bar's runner (cat/chicken/...). The pick is kept
# in $HYPRFLOW_STATE/runner, which the Quickshell bar's Runcat module watches
# (it switches at once), and written into Waybar's runcat-runner.css too.
set -uo pipefail

# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../lib/common.sh"

CONFIG_FILE="${RUNCAT_RUNNER_CSS:-$HOME/.config/waybar/runcat-runner.css}"

RUNNERS=(
    "Cat:runcat"
    "Chicken:runcat-chicken"
)

build_list() {
    local entry
    for entry in "${RUNNERS[@]}"; do
        printf '%s\n' "${entry%%:*}"
    done
}

apply_runner() {
    local font_family="$1"

    if ! grep -qE "^#custom-hardware-wrap[[:space:]].*font-family:[[:space:]]*'[^']*'" "$CONFIG_FILE"; then
        echo "pet-picker: no #custom-hardware-wrap font-family line found in $CONFIG_FILE" >&2
        return 1
    fi

    sed -i -E "s/(^#custom-hardware-wrap[[:space:]].*font-family:[[:space:]]*')[^']*(')/\1${font_family}\2/" "$CONFIG_FILE"
}

remember_runner() {
    mkdir -p "$HYPRFLOW_STATE" && printf '%s\n' "$1" > "$HYPRFLOW_STATE/runner"
}

main() {
    local name font_family entry

    name=$(build_list | fzf \
        --prompt="  Pick a runner > " \
        --height=30% \
        --border=rounded \
        --layout=reverse \
        --no-info \
        --color="$("$HYPRFLOW_LIB/fzf-colors.sh")")

    [ -z "$name" ] && exit 0

    font_family=""
    for entry in "${RUNNERS[@]}"; do
        if [ "${entry%%:*}" = "$name" ]; then
            font_family="${entry#*:}"
            break
        fi
    done

    if [ -z "$font_family" ]; then
        echo "pet-picker: unknown runner '$name'" >&2
        exit 1
    fi

    remember_runner "$font_family"
    # Waybar's copy, when there is one. SIGUSR2 only refreshes module data,
    # not the CSS stylesheet (see wallust-theme-manager.sh); font-family needs
    # a full restart. With the Quickshell bar on, bar-restart.sh starts nothing.
    if [ -f "$CONFIG_FILE" ] && ! apply_runner "$font_family"; then
        command -v notify-send >/dev/null && notify-send -i "dialog-error" "Pet Picker" "Failed to apply runner: $name"
        exit 1
    fi
    [ -f "$CONFIG_FILE" ] && "$HYPRFLOW_LIB/bar-restart.sh"
    command -v notify-send >/dev/null && notify-send -i "preferences-desktop-theme" "Pet Picker" "Applied runner: $name"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
