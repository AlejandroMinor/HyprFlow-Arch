#!/usr/bin/env bash
#
# Ensures ~/.config/hypr/avatar.png exists. An existing file is never touched;
# --force regenerates the Arch glyph fallback over it.

set -uo pipefail

readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly HYPR_DIR="$CONFIG_DIR/hypr"
readonly AVATAR_FILE="$HYPR_DIR/avatar.png"
readonly THEME_FILE="$HYPR_DIR/hyprlock-theme.conf"
readonly ARCH_GLYPH_CODEPOINT=''

# Script-scoped, not local to main: the trap fires after main returns, and a
# local would already be out of scope -- leaking the directory every run.
temp_dir=""
trap '[ -n "$temp_dir" ] && rm -rf "$temp_dir"' EXIT

main() {
    [ "${1:-}" = "--force" ] || [ ! -f "$AVATAR_FILE" ] || return 0
    command -v magick >/dev/null 2>&1 || return 0

    mkdir -p "$HYPR_DIR" || return 0

    local foreground font_file
    foreground="$(read_foreground)"
    font_file="$(fc-match -f '%{file}' 'JetBrainsMono Nerd Font' 2>/dev/null)"
    [ -n "$font_file" ] && [ -f "$font_file" ] || return 0

    temp_dir="$(mktemp -d)" || return 0

    create_mask "$font_file" "$temp_dir/mask.png" || return 0
    compose_avatar "$temp_dir/mask.png" "$foreground" "$AVATAR_FILE" || return 0
}

read_foreground() {
    local colour
    colour="$(sed -n 's/^\$fg *= *rgb(\([0-9A-Fa-f]\{6\}\)).*/#\1/p' \
        "$THEME_FILE" 2>/dev/null | head -n 1)"
    printf '%s' "${colour:-#efe9dc}"
}

# The glyph is drawn white on black, and that greyscale becomes the alpha mask.
# connected-components removes a stray speck the font renders beside the logo --
# tiny, but visible once scaled down to avatar size.
create_mask() {
    local font_file=$1
    local out_file=$2

    magick -size 256x256 xc:black \
        -font "$font_file" -pointsize 150 -fill white \
        -gravity center -annotate +0+0 "$(printf '%s' "$ARCH_GLYPH_CODEPOINT")" \
        -alpha off -colorspace gray \
        -define connected-components:area-threshold=300 \
        -define connected-components:mean-color=true \
        -connected-components 8 \
        -trim +repage -resize 150x150 \
        -gravity center -background black -extent 256x256 \
        "$out_file" 2>/dev/null
}

compose_avatar() {
    local mask_file=$1
    local foreground=$2
    local out_file=$3

    magick "$mask_file" -colorspace gray -alpha off \
        \( +clone -fill "$foreground" -colorize 100 \) +swap \
        -alpha off -compose copy_opacity -composite \
        "$out_file" 2>/dev/null
}

main "$@"
