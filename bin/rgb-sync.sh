#!/usr/bin/env bash
# shellcheck disable=SC2154  # color0..15 come from the wallust palette (load_palette)

# Paint every OpenRGB device to match the current theme.
#
#   rgb-sync.sh IMAGE   take the dominant vivid hue of the wallpaper
#   rgb-sync.sh         take it from the wallust palette (static themes)
#   rgb-sync.sh --last  re-apply the last colour sent (session start)
#   rgb-sync.sh --reset back to the factory rainbow; --last undoes it
#   rgb-sync.sh --off   every LED off (game mode); --last undoes it
#   rgb-sync.sh --toggle  --off, or --last when they are off already
#   rgb-sync.sh --rescan  detect devices again (a headset just turned on),
#                         then --last, or --off while they are off
#
# Talks to the OpenRGB server on localhost (openrgb.service, see
# system/openrgb.service.d/). Without it the CLI rescans the hardware on every
# call, which takes ~15 s and cannot reach the NVMe LEDs as a normal user, so
# this quietly does nothing instead (but waits for one still starting).

# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
LAST="$HOME/.cache/wallust/led-color"
LIGHTS_OFF="$HOME/.cache/wallust/led-off"  # there while --off holds

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

# Whether $1 is a colour this script can use: RRGGBB, with or without a #.
is_hex() {
    [[ ${1#\#} =~ ^[0-9A-Fa-f]{6}$ ]]
}

# Sets r g b max min from a #RRGGBB colour; fails, setting nothing, on anything
# else. Globals on purpose: the callers read all five right after.
split() {
    is_hex "$1" || return 1
    local hex="${1#\#}"
    r=$((16#${hex:0:2})) g=$((16#${hex:2:2})) b=$((16#${hex:4:2}))
    max=$r; (( g > max )) && max=$g; (( b > max )) && max=$b
    min=$r; (( g < min )) && min=$g; (( b < min )) && min=$b
    return 0
}

# Prints the LED colour for the wallust palette: color5 (the accent, as on the
# Arch icon and the active border), or the palette colour with the highest
# chroma when color5 is under 30% saturation.
palette_colour() {
    load_palette || return 1

    split "$color5" || return 1
    if (( max == 0 || (max - min) * 100 < max * 30 )); then
        local best="$color5" best_chroma=$(( max - min )) i var
        for i in {1..15}; do
            var="color$i"
            split "${!var}" || continue
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

# Puts every device on its rainbow effect, or its colour cycle when it has no
# rainbow (mice usually). Modes are read from the server rather than assumed,
# since device numbers and mode sets differ from one machine to the next. The
# cached colour is left alone, so --last brings the theme back.
reset_to_factory() {
    local args=()
    mapfile -t args < <(openrgb -ld 2>/dev/null | awk '
        /^[0-9]+:/ { dev = $1; sub(":", "", dev) }
        /^ *Modes:/ {
            mode = ""
            if ($0 ~ /Rainbow/) mode = "rainbow"
            else if ($0 ~ /Spectrum Cycle/) mode = "spectrum cycle"
            if (mode != "") print "-d\n" dev "\n-m\n" mode
        }')
    [ ${#args[@]} -gt 0 ] && openrgb "${args[@]}" >/dev/null 2>&1
}

# Switches every LED off: the device's Off mode, or static black when it has
# none. Leaves the cached colour for --last; fails when no device came back.
lights_off() {
    local args=()
    mapfile -t args < <(openrgb -ld 2>/dev/null | awk '
        /^[0-9]+:/ { dev = $1; sub(":", "", dev) }
        /^ *Modes:/ {
            if ($0 ~ / \[?Off\]? /) print "-d\n" dev "\n-m\noff"
            else print "-d\n" dev "\n-m\nstatic\n-c\n000000"
        }')
    [ ${#args[@]} -gt 0 ] && openrgb "${args[@]}" >/dev/null 2>&1
}

command -v openrgb >/dev/null 2>&1 || exit 0

# Something listening on the OpenRGB port (RGB_PORT: for the tests).
server_up() { (exec 3<>/dev/tcp/127.0.0.1/"${RGB_PORT:-6742}") 2>/dev/null; }

# True once the server answers. openrgb.service opens its port ~20 s after it
# starts (hardware scan), so a session start waits; with the service not
# running there is nothing to wait for and it gives up at once.
wait_for_server() {
    local waited=0
    until server_up; do
        command -v systemctl >/dev/null 2>&1 &&
            systemctl is-active --quiet openrgb.service || return 1
        (( waited++ >= ${RGB_WAIT_STEPS:-60} )) && return 1
        sleep 0.5
    done
}

# Asks the server to detect devices again and waits until it is done. The
# server only detects at start, so a device off back then is missing.
rescan() {
    python3 - "${RGB_PORT:-6742}" "${RGB_RESCAN_WAIT:-60}" <<'EOF' 2>/dev/null
import socket, struct, sys

PROTOCOL, SET_NAME, RESCAN, DETECTION_DONE = 40, 50, 140, 103

def send(sock, packet, data=b""):
    sock.sendall(b"ORGB" + struct.pack("<III", 0, packet, len(data)) + data)

def receive(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise OSError("closed")
        data += chunk
    return data

sock = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=float(sys.argv[2]))
send(sock, PROTOCOL, struct.pack("<I", 6))
send(sock, SET_NAME, b"rgb-sync\0")
send(sock, RESCAN)
while True:
    packet, size = struct.unpack("<II", receive(sock, 16)[8:16])
    receive(sock, size)
    if packet == DETECTION_DONE:
        break
EOF
}

if [ "${1:-}" = "--rescan" ]; then
    wait_for_server || exit 0
    rescan
    if [ -e "$LIGHTS_OFF" ]; then set -- --off; else set -- --last; fi
fi

if [ "${1:-}" = "--toggle" ]; then
    if [ -e "$LIGHTS_OFF" ]; then set -- --last; else set -- --off; fi
fi

case "$1" in
    --reset|--off)
        wait_for_server || exit 0
        if [ "$1" = "--reset" ]; then reset_to_factory; exit 0; fi
        # Marked only if they went off: --toggle reads it.
        lights_off && mkdir -p "$(dirname "$LIGHTS_OFF")" && : > "$LIGHTS_OFF"
        exit 0 ;;
esac

case "$1" in
    # An empty or damaged cache (a crash mid write) falls back to the palette.
    --last) led=$(cat "$LAST" 2>/dev/null); is_hex "$led" || led=$(palette_colour) ;;
    "")     led=$(palette_colour) ;;
    *)      led=$(dominant_hue "$1") || led=$(palette_colour) ;;
esac
[ -n "$led" ] || exit 0

# Cached first, so --last can apply it later if the server never answers.
mkdir -p "$(dirname "$LAST")" && echo "$led" > "$LAST"

wait_for_server || exit 0
openrgb -m static -c "$led" >/dev/null 2>&1 && rm -f "$LIGHTS_OFF"
