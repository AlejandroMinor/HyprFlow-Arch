#!/usr/bin/env bash

THEME="$HOME/.config/cava/themes/wallust"
CONF="$HOME/.config/cava/waybar.conf"
#CHARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")  # bars
CHARS=("⡀" "⣀" "⣄" "⣤" "⣦" "⣶" "⣷" "⣿")  # braille dots

# opacity of the idle baseline when there is no signal
IDLE_ALPHA="35%"

mapfile -t COLORS < <(grep 'gradient_color_' "$THEME" 2>/dev/null | sed "s/.*= '//;s/'//")
NUM_COLORS=${#COLORS[@]}

while true; do
    cava -p "$CONF" | while IFS= read -r line; do
        # the module width must stay constant: always render every bar,
        # including the ones at 0. Otherwise waybar collapses the module
        # to 0px on every silence and shoves the rest of the bar around.
        markup=""
        silent=1
        for val in $line; do
            [[ "$val" == "0" ]] || silent=0
            char="${CHARS[$val]}"
            if [[ $NUM_COLORS -gt 0 ]]; then
                color_idx=$(( val * (NUM_COLORS - 1) / 7 ))
                color="${COLORS[$color_idx]}"
                markup+="<span color='${color}'>${char}</span>"
            else
                markup+="$char"
            fi
        done

        [[ -z "$markup" ]] && continue

        if [[ $silent -eq 1 ]]; then
            echo "{\"text\": \"<span alpha='${IDLE_ALPHA}'>$markup</span>\", \"class\": \"idle\"}"
        else
            echo "{\"text\": \"$markup\", \"class\": \"active\"}"
        fi
    done
    sleep 1
done
