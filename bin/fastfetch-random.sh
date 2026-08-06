#!/usr/bin/env bash
# Runs fastfetch with a random ascii art logo from ascii_art/.
set -uo pipefail

ASCII_DIR="${FASTFETCH_ASCII_DIR:-$HOME/HyprFlow-Arch/dotconfig/fastfetch/ascii_art}"
CONFIG_FILE="${FASTFETCH_CONFIG:-$HOME/.config/fastfetch/config.jsonc}"
ARCH_BUILTIN="__arch_builtin__"

mapfile -t ARTS < <(find "$ASCII_DIR" -maxdepth 1 -type f | sort)

# include the built-in Arch logo as one more option in the pool
ARTS+=("$ARCH_BUILTIN")

logo="${ARTS[RANDOM % ${#ARTS[@]}]}"

if [ "$logo" = "$ARCH_BUILTIN" ]; then
    exec fastfetch --config "$CONFIG_FILE" --logo-type builtin --logo arch "$@"
fi

exec fastfetch --config "$CONFIG_FILE" --file "$logo" "$@"
