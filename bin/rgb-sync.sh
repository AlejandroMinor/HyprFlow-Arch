#!/usr/bin/env bash

# Paint every OpenRGB device to match the current theme.
#
#   rgb-sync.sh IMAGE   take the dominant vivid hue of the wallpaper
#   rgb-sync.sh         take it from the wallust palette (static themes)
#   rgb-sync.sh --last  re-apply the last colour sent (session start)
#
# Talks to the OpenRGB server on localhost (openrgb.service, see
# system/openrgb.service.d/). Without it the CLI rescans the hardware on every
# call, which takes ~15 s and cannot reach the NVMe LEDs as a normal user, so
# this quietly does nothing instead.

COLORS="$HOME/.cache/wallust/colors/colors-rofi-sh.conf"
LAST="$HOME/.cache/wallust/led-color"

# Prints the hue covering the most area among saturated, lit pixels, at full
# saturation and value. Area beats wallust's palette here: the palette is
# tuned for readable text and often misses the wallpaper's overall mood (a
# purple sunset can come out red). Animated GIFs are read from their first
# frame. Exits non-zero when the file is not an image (video wallpapers such
# as .mp4), and prints FFFFFF for images with no real colour.
dominant_hue() {
    python3 - "$1" <<'EOF' 2>/dev/null
import colorsys, sys
from PIL import Image

BINS = 24
img = Image.open(sys.argv[1]).convert("RGB")
img.thumbnail((200, 200))

weight = [0.0] * BINS
hue_sum = [0.0] * BINS
colourful = 0
pixels = list(img.convert("HSV").getdata())
for h, s, v in pixels:
    if s > 89 and v > 63:  # saturation > 35%, value > 25%
        w = s * v
        k = h * BINS // 256
        weight[k] += w
        hue_sum[k] += h * w
        colourful += 1

if colourful < len(pixels) / 100:
    print("FFFFFF")
    sys.exit()

k = max(range(BINS), key=weight.__getitem__)
r, g, b = colorsys.hsv_to_rgb(hue_sum[k] / weight[k] / 256, 1, 1)
print("%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255)))
EOF
}

# Sets r g b max min from a #RRGGBB colour.
split() {
    local hex="${1#\#}"
    r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
    max=$r; (( g > max )) && max=$g; (( b > max )) && max=$b
    min=$r; (( g < min )) && min=$g; (( b < min )) && min=$b
}

# Prints the LED colour for the wallust palette: color5 (the accent, as on the
# Arch icon and the active border), or the palette colour with the highest
# chroma when color5 is under 30% saturation.
palette_colour() {
    [ -f "$COLORS" ] || return 1
    # shellcheck source=/dev/null
    . "$COLORS"

    split "$color5"
    if (( max == 0 || (max - min) * 100 < max * 30 )); then
        local best="$color5" best_chroma=$(( max - min )) i var
        for i in {1..15}; do
            var="color$i"
            split "${!var}"
            (( max - min > best_chroma )) && best="${!var}" best_chroma=$(( max - min ))
        done
        split "$best"
    fi

    # LEDs cannot show dark or greyish colours; they wash out to a pale white.
    # Keep only the hue and push saturation and value to 100%, which is just
    # stretching each channel over [min, max]. Near-grey picks (saturation
    # under 15%) have no meaningful hue, so they go white.
    if (( max == 0 || (max - min) * 100 < max * 15 )); then
        echo "FFFFFF"
    else
        printf '%02X%02X%02X\n' \
            $(( (r - min) * 255 / (max - min) )) \
            $(( (g - min) * 255 / (max - min) )) \
            $(( (b - min) * 255 / (max - min) ))
    fi
}

command -v openrgb >/dev/null 2>&1 || exit 0

case "$1" in
    --last) led=$(cat "$LAST" 2>/dev/null) || led=$(palette_colour) ;;
    "")     led=$(palette_colour) ;;
    *)      led=$(dominant_hue "$1") || led=$(palette_colour) ;;
esac
[ -n "$led" ] || exit 0

# Cached before the server check, so a session start that finds the server
# still scanning can re-apply it later with --last.
echo "$led" > "$LAST"

(exec 3<>/dev/tcp/127.0.0.1/6742) 2>/dev/null || exit 0
openrgb -m static -c "$led" >/dev/null 2>&1
