#!/usr/bin/env bash
# Interactive picker for the custom/hardware-wrap runner (cat/chicken/...).
set -uo pipefail

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

main() {
    local name font_family entry

    name=$(build_list | fzf \
        --prompt="  Pick a runner > " \
        --height=30% \
        --border=rounded \
        --layout=reverse \
        --no-info \
        --color='bg+:#1a1b26,bg:#0f0f0f,hl:#7aa2f7,fg:#c0caf5,hl+:#bb9af7,prompt:#7aa2f7,pointer:#f7768e')

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

    if apply_runner "$font_family"; then
        killall -SIGUSR2 waybar 2>/dev/null || true
        notify-send -i "preferences-desktop-theme" "Pet Picker" "Applied runner: $name"
    else
        notify-send -i "dialog-error" "Pet Picker" "Failed to apply runner: $name"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
