#!/usr/bin/env python3
"""The BY Tech keyboard's lights (see hyprflow/keyboard_rgb.py).

    keyboard-rgb.py color RRGGBB   the nearest palette colour, full brightness
    keyboard-rgb.py off            dark (brightness 0)
    keyboard-rgb.py rainbow        multicolour, full brightness
    keyboard-rgb.py effect N       switch to effect N, in the theme's colour
    keyboard-rgb.py --json         the effects, the one in use marked, and the
                                   theme colour as the keyboard shows it

rgb-sync.sh runs the first three next to OpenRGB; Super+K's "Keyboard
effect" panel the last two. Without the keyboard plugged in it does nothing
(--json lists no effects).
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import keyboard_rgb, paths  # noqa: E402

LAST = paths.CACHE / "wallust" / "led-color"
LIGHTS_OFF = paths.CACHE / "wallust" / "led-off"


def theme_colour():
    """The palette index of rgb-sync's last colour; white without one."""
    try:
        return keyboard_rgb.nearest(LAST.read_text().strip())
    except (OSError, ValueError):
        return 6


def run(keyboard, args):
    match args:
        case ["color", hex_colour]:
            keyboard.set_light(keyboard_rgb.nearest(hex_colour), keyboard_rgb.MAX_BRIGHTNESS)
        case ["off"]:
            keyboard.set_light(brightness=0)
        case ["rainbow"]:
            keyboard.set_light(keyboard_rgb.MULTICOLOUR, keyboard_rgb.MAX_BRIGHTNESS)
        case ["effect", number]:
            keyboard.set_effect(int(number))
            dark = LIGHTS_OFF.exists()
            keyboard.set_light(theme_colour(), 0 if dark else keyboard_rgb.MAX_BRIGHTNESS)
        case ["--json"]:
            current = keyboard.effect()
            print(json.dumps({
                "color": keyboard_rgb.PALETTE[theme_colour()][2],
                "effects": [{"number": n, "name": name, "current": n == current}
                            for n, name in enumerate(keyboard_rgb.EFFECTS, 1)],
            }))
        case _:
            print(__doc__.strip(), file=sys.stderr)
            return 2
    return 0


def main(args, device=None):
    # Composition root: the tests pass a fake device.
    if device is None:
        path = keyboard_rgb.find()
        if path is None:
            if args[:1] == ["--json"]:
                print('{"effects": []}')
            return 0
        try:
            device = keyboard_rgb.Hidraw(path)
        except OSError as e:
            print(f"keyboard-rgb: {path}: {e.strerror} (see docs/optional-setup.md)", file=sys.stderr)
            return 1
    try:
        return run(keyboard_rgb.Keyboard(device), args)
    except (OSError, ValueError) as e:
        print(f"keyboard-rgb: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
