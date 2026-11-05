#!/usr/bin/env bash
# Runs fastfetch with a random logo: ascii art, an image or a GIF, from any
# folder under ~/.config/fastfetch, symlinked ones included (a clone of the
# logos repository linked there, say). Skipped: originals/ (the full-size files
# the resized ones come from), tools/ and hidden folders. A logo found twice
# under the same name counts once.
set -uo pipefail

FASTFETCH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
LOGOS_DIR="${FASTFETCH_LOGOS_DIR:-$FASTFETCH_DIR}"
CONFIG_FILE="${FASTFETCH_CONFIG:-$FASTFETCH_DIR/config.jsonc}"
ARCH_BUILTIN="__arch_builtin__"

mapfile -t ARTS < <(
    find -L "$LOGOS_DIR" -mindepth 1 -type d \( -name originals -o -name tools -o -name '.*' \) -prune -o \
        -type f \( -iname '*.txt' -o -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
                   -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) -print 2>/dev/null |
        sort | awk -F/ '!seen[$NF]++'
)

# include the built-in Arch logo as one more option in the pool
ARTS+=("$ARCH_BUILTIN")

logo="${ARTS[RANDOM % ${#ARTS[@]}]}"

if [ "$logo" = "$ARCH_BUILTIN" ]; then
    exec fastfetch --config "$CONFIG_FILE" --logo-type builtin --logo arch "$@"
fi

case "${logo,,}" in
    *.gif)
        # 0 plays the animation (kitty, fastfetch 2.69+); the default is the first frame.
        exec fastfetch --config "$CONFIG_FILE" --kitty "$logo" --logo-animation-frame 0 "$@"
        ;;
    *.png|*.jpg|*.jpeg|*.webp|*.bmp)
        exec fastfetch --config "$CONFIG_FILE" --kitty "$logo" "$@"
        ;;
    *)
        exec fastfetch --config "$CONFIG_FILE" --file "$logo" "$@"
        ;;
esac
