#!/usr/bin/env bash
#
#   --title / --subtitle   text lines, empty when nothing is playing
#   --art / --art-now      path to a 256x256 PNG; --art-now never downloads
#
# Privacy: only apps whose desktop entry declares Music without WebBrowser or
# Video reveal track details. Everything else shows its name and icon.

set -uo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprflow"
PLACEHOLDER="$CACHE_DIR/lockart-none.png"
DESKTOP_DIRS=(
    "$HOME/.local/share/applications"
    /usr/share/applications
    /var/lib/flatpak/exports/share/applications
)

command -v playerctl >/dev/null 2>&1 || exit 0
mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

metadata() { playerctl metadata --format "$1" 2>/dev/null; }

print_placeholder() {
    [ -s "$PLACEHOLDER" ] || magick -size 256x256 xc:none "$PLACEHOLDER" 2>/dev/null
    printf '%s\n' "$PLACEHOLDER"
}

player_id=$(metadata '{{playerName}}')
if [ -z "$player_id" ]; then
    # Both art modes must print a path even here: hyprlock takes reload_cmd
    # output as the image path, and nothing means "keep what is on screen".
    case "${1:-}" in
        --art|--art-now) print_placeholder ;;
    esac
    exit 0
fi

# playerctl strips the instance suffix the bus name carries (edge.instance821099).
player_bus_name() {
    busctl --user list 2>/dev/null \
        | grep -o "org\.mpris\.MediaPlayer2\.${player_id%%.*}[^ ]*" \
        | head -1
}

locate_desktop_entry() {
    local base="${player_id%%.*}" declared="" bus dir match

    bus=$(player_bus_name)
    if [ -n "$bus" ]; then
        declared=$(busctl --user get-property "$bus" /org/mpris/MediaPlayer2 \
            org.mpris.MediaPlayer2 DesktopEntry 2>/dev/null)
        declared=${declared#s \"}
        declared=${declared%\"}
    fi

    for dir in "${DESKTOP_DIRS[@]}"; do
        [ -n "$declared" ] && [ -f "$dir/$declared.desktop" ] && {
            printf '%s' "$dir/$declared.desktop"
            return 0
        }
        [ -f "$dir/$base.desktop" ] && {
            printf '%s' "$dir/$base.desktop"
            return 0
        }
    done

    # Edge implements neither DesktopEntry nor Identity and announces itself as
    # "edge" while shipping microsoft-edge.desktop.
    for dir in "${DESKTOP_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        match=$(find "$dir" -maxdepth 1 -name "*$base*.desktop" 2>/dev/null | sort | head -1)
        [ -n "$match" ] && { printf '%s' "$match"; return 0; }
    done

    return 1
}

# Resolved here, not memoised inside desktop_field: its callers use command
# substitution, so a cache written there would die with the subshell.
DESKTOP_ENTRY=$(locate_desktop_entry) || DESKTOP_ENTRY=""

desktop_field() {
    [ -n "$DESKTOP_ENTRY" ] || return 1
    sed -n "s/^$1=//p" "$DESKTOP_ENTRY" | head -1
}

is_music_app() {
    local categories
    categories=$(desktop_field Categories) || return 1
    # Delimited so tokens match whole: a bare *Video* glob also matches the
    # AudioVideo category that music players declare.
    categories=";${categories%;};"

    case "$categories" in
        *";WebBrowser;"*|*";Video;"*) return 1 ;;
        *";Music;"*) return 0 ;;
    esac

    return 1
}

app_display_name() {
    local name base
    name=$(desktop_field Name) && [ -n "$name" ] && {
        printf '%s' "$name"
        return
    }

    base="${player_id%%.*}"
    printf '%s' "$(printf '%s' "${base:0:1}" | tr '[:lower:]' '[:upper:]')${base:1}"
}

PLAYBACK_STATUS=$(playerctl status 2>/dev/null) || PLAYBACK_STATUS=""

playback_icon() {
    case "$PLAYBACK_STATUS" in
        Playing) printf '󰐊' ;;
        Paused)  printf '󰏤' ;;
        *)       printf '󰎆' ;;
    esac
}

find_icon_file() {
    local name="$1" dir file
    [ -n "$name" ] || return 1
    [ -f "$name" ] && { printf '%s' "$name"; return 0; }

    for dir in /usr/share/icons/hicolor/scalable/apps \
               /usr/share/icons/hicolor/512x512/apps \
               /usr/share/icons/hicolor/256x256/apps \
               /usr/share/icons/hicolor/128x128/apps \
               /usr/share/icons/hicolor/64x64/apps \
               /usr/share/pixmaps
    do
        for file in "$dir/$name.svg" "$dir/$name.png" "$dir/$name.xpm"; do
            [ -f "$file" ] && { printf '%s' "$file"; return 0; }
        done
    done

    file=$(find /usr/share/icons \( -name "$name.png" -o -name "$name.svg" \) 2>/dev/null | head -1)
    [ -n "$file" ] && { printf '%s' "$file"; return 0; }

    return 1
}

app_icon_file() {
    local icon
    icon=$(desktop_field Icon) || return 1
    find_icon_file "$icon"
}

# Where a given artwork source caches to. Derived from the source, so the path
# changes whenever the artwork does: hyprlock only reloads the image when
# reload_cmd returns a path different from the one on screen.
cached_art_path() {
    printf '%s/lockart-%s.png' "$CACHE_DIR" \
        "$(printf '%s' "$1" | md5sum | cut -c1-16)"
}

cache_as_png() {
    local source="$1" target temp local_path
    target=$(cached_art_path "$source")
    [ -s "$target" ] && { printf '%s\n' "$target"; return 0; }

    temp=$(mktemp) || return 1
    case "$source" in
        http://*|https://*)
            # The player already fetched it; the timeout keeps a slow network
            # from stalling the lockscreen refresh.
            curl -sfL --max-time 5 -o "$temp" "$source" 2>/dev/null ;;
        file://*)
            local_path=$(printf '%b' "${source#file://}" | sed 's/%\([0-9A-Fa-f]\{2\}\)/\\x\1/g')
            local_path=$(printf '%b' "$local_path")
            [ -f "$local_path" ] && cp "$local_path" "$temp" ;;
        *)
            [ -f "$source" ] && cp "$source" "$temp" ;;
    esac

    if [ -s "$temp" ] && magick "$temp" -background none -resize 256x256^ \
        -gravity center -extent 256x256 "$target" 2>/dev/null
    then
        rm -f "$temp"
        find "$CACHE_DIR" -maxdepth 1 -name 'lockart-*.png' \
            ! -name "$(basename "$target")" ! -name "$(basename "$PLACEHOLDER")" \
            -delete 2>/dev/null
        printf '%s\n' "$target"
        return 0
    fi

    rm -f "$temp"
    return 1
}

# Each branch fetches only what it prints. These labels refresh every few
# seconds under the lock, so a --title call must not pay for artwork lookups.
case "${1:---title}" in
    --title)
        if is_music_app; then
            title=$(metadata '{{title}}')
            [ -n "$title" ] && printf '%.42s\n' "$title"
        else
            printf '%.42s\n' "$(app_display_name)"
        fi
        ;;

    --subtitle)
        if is_music_app; then
            artist=$(metadata '{{artist}}')
            [ -n "$artist" ] && printf '%s  %.36s\n' "$(playback_icon)" "$artist"
        else
            case "$PLAYBACK_STATUS" in
                Playing|Paused) printf '%s  %s\n' "$(playback_icon)" "$PLAYBACK_STATUS" ;;
            esac
        fi
        ;;

    --art|--art-now)
        if is_music_app; then
            source=$(metadata '{{mpris:artUrl}}')
        else
            source=$(app_icon_file) || source=""
        fi

        if [ -z "$source" ]; then
            print_placeholder
            exit 0
        fi

        # hyprlock shows the config's path until reload_time first elapses, so
        # a cached cover resolved here is on screen the instant the lock opens.
        if [ "$1" = "--art-now" ]; then
            cached=$(cached_art_path "$source")
            [ -s "$cached" ] && printf '%s\n' "$cached" || print_placeholder
            exit 0
        fi

        cache_as_png "$source" || print_placeholder
        ;;
esac
