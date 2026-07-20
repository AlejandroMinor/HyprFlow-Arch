#!/usr/bin/env bash
#
# Usage: backdrop.sh [--blocking] <wallpaper> <width> <height> <band-height>
#
# hyprlock blurs only whole backgrounds and shapes cannot frost what is behind
# them, so the band is baked into an image here.

set -uo pipefail

main() {
    local blocking=false
    if [ "${1:-}" = "--blocking" ]; then
        blocking=true
        shift
    fi

    local wallpaper=${1:-}
    local screen_width=${2:-}
    local screen_height=${3:-}
    local band_height=${4:-}

    local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/hyprflow"

    if ! can_build "$wallpaper"; then
        printf '%s' "$wallpaper"
        return 0
    fi

    mkdir -p "$cache_dir" 2>/dev/null || {
        printf '%s' "$wallpaper"
        return 0
    }

    local signature backdrop lock_file
    signature="$(make_signature "$wallpaper" "$screen_width" "$screen_height" "$band_height")"
    backdrop="$cache_dir/lockbg-$signature.jpg"
    lock_file="$cache_dir/lockbg-$signature.building"

    if [ -s "$backdrop" ]; then
        printf '%s' "$backdrop"
        return 0
    fi

    if [ "$blocking" = true ]; then
        if build_backdrop "$wallpaper" "$screen_width" "$screen_height" "$band_height" "$backdrop" "$cache_dir"; then
            printf '%s' "$backdrop"
        else
            printf '%s' "$wallpaper"
        fi
        return 0
    fi

    # Building takes seconds; the lock must not wait. The next lock picks it up.
    start_background_build "$0" "$lock_file" "$wallpaper" "$screen_width" "$screen_height" "$band_height"
    printf '%s' "$wallpaper"
}

can_build() {
    local wallpaper=$1
    [ -f "$wallpaper" ] && command -v magick >/dev/null 2>&1
}

# The mtime is in the key because editing an image in place keeps its path.
make_signature() {
    local wallpaper=$1
    local screen_width=$2
    local screen_height=$3
    local band_height=$4
    local mtime

    mtime=$(stat -c %Y "$wallpaper" 2>/dev/null || printf '')
    printf '%s %s %s %s %s' \
        "$wallpaper" "$screen_width" "$screen_height" "$band_height" "$mtime" \
        | md5sum | cut -c1-16
}

build_backdrop() {
    local wallpaper=$1
    local screen_width=$2
    local screen_height=$3
    local band_height=$4
    local backdrop=$5
    local cache_dir=$6

    local fade_height=$(( band_height / 3 ))
    local solid_height=$(( band_height - fade_height ))
    # JPEG, not PNG: encoding a full-screen PNG alone costs over a second.
    local temp="$backdrop.partial.jpg"

    # The band blurs at reduced size and scales back up, matching a large radius
    # far more cheaply.
    magick "$wallpaper" \
        -resize "${screen_width}x${screen_height}^" \
        -gravity center -extent "${screen_width}x${screen_height}" \
        \( -clone 0 -gravity south -crop "${screen_width}x${band_height}+0+0" +repage \
           -resize 40% -blur 0x5 -resize "${screen_width}x${band_height}!" \
           -brightness-contrast -12x-5 \
           \( -size "${screen_width}x${fade_height}" gradient:black-white \
              \( -size "${screen_width}x${solid_height}" xc:white \) -append \
           \) -alpha off -compose copy_opacity -composite \
        \) \
        -gravity south -compose over -composite \
        -quality 92 "$temp" 2>/dev/null || {
            rm -f "$temp"
            return 1
        }

    mv -f "$temp" "$backdrop" || return 1

    find "$cache_dir" -maxdepth 1 -name 'lockbg-*.jpg' \
        ! -name "$(basename "$backdrop")" -delete 2>/dev/null

    return 0
}

start_background_build() {
    local script=$1
    local lock_file=$2
    local wallpaper=$3
    local screen_width=$4
    local screen_height=$5
    local band_height=$6

    # mkdir is the mutex: it succeeds for exactly one caller.
    if mkdir "$lock_file" 2>/dev/null; then
        setsid bash -c '
            trap "rmdir \"$1\" 2>/dev/null" EXIT
            "$0" --blocking "$2" "$3" "$4" "$5" >/dev/null 2>&1
        ' "$(readlink -f "$script")" "$lock_file" "$wallpaper" \
           "$screen_width" "$screen_height" "$band_height" >/dev/null 2>&1 &
    fi
}

main "$@"
