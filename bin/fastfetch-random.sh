#!/usr/bin/env bash
# Runs fastfetch with a random ascii art or image logo from ascii_art/ + img_art/.
set -uo pipefail

FASTFETCH_DIR="$HOME/HyprFlow-Arch/dotconfig/fastfetch"
ASCII_DIR="${FASTFETCH_ASCII_DIR:-$FASTFETCH_DIR/ascii_art}"
IMG_DIR="${FASTFETCH_IMG_DIR:-$FASTFETCH_DIR/img_art}"
CONFIG_FILE="${FASTFETCH_CONFIG:-$HOME/.config/fastfetch/config.jsonc}"
ARCH_BUILTIN="__arch_builtin__"

mapfile -t ARTS < <(find "$ASCII_DIR" "$IMG_DIR" -maxdepth 1 -type f | sort)

# include the built-in Arch logo as one more option in the pool
ARTS+=("$ARCH_BUILTIN")

logo="${ARTS[RANDOM % ${#ARTS[@]}]}"

if [ "$logo" = "$ARCH_BUILTIN" ]; then
    exec fastfetch --config "$CONFIG_FILE" --logo-type builtin --logo arch "$@"
fi

case "$logo" in
    *.png|*.jpg|*.jpeg|*.webp|*.bmp|*.gif)
        exec fastfetch --config "$CONFIG_FILE" --kitty "$logo" "$@"
        ;;
    *)
        exec fastfetch --config "$CONFIG_FILE" --file "$logo" "$@"
        ;;
esac
