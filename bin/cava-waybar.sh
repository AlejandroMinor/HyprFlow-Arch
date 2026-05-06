#!/usr/bin/env bash

THEME="$HOME/.config/cava/themes/wallust"
CHARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

mapfile -t COLORS < <(grep 'gradient_color_' "$THEME" 2>/dev/null | sed "s/.*= '//;s/'//")
NUM_COLORS=${#COLORS[@]}

cava -p "$HOME/.config/cava/waybar.conf" | while IFS= read -r line; do
    stripped=$(echo "$line" | tr -d ' ')
    if [[ "$stripped" =~ ^0*$ ]] || [[ -z "$stripped" ]]; then
        echo '{"text": "", "class": "empty"}'
        continue
    fi

    markup=""
    for val in $line; do
        char="${CHARS[$val]}"
        if [[ $NUM_COLORS -gt 0 ]]; then
            color_idx=$(( val * (NUM_COLORS - 1) / 7 ))
            color="${COLORS[$color_idx]}"
            markup+="<span color='${color}'>${char}</span>"
        else
            markup+="$char"
        fi
    done

    echo "{\"text\": \"$markup\", \"class\": \"active\"}"
done
