#!/usr/bin/env python3
"""Audio visualizer for Waybar (continuous: no interval).

cava prints one line per frame, a height from 0 to 7 per bar
(~/.config/cava/waybar.conf); each becomes a braille glyph colored from the
wallust cava palette, the higher the warmer. It runs on WaybarModule, so it
dies with the Waybar that started it and takes cava along: the shell version
it replaces piled up a copy per Waybar restart.
"""

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from waybar_module import WaybarModule, lines  # noqa: E402

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "cava"
CONF = CONFIG / "waybar.conf"
THEME = CONFIG / "themes" / "wallust"

GLYPHS = "⡀⣀⣄⣤⣦⣶⣷⣿"   # heights 0..7
IDLE_ALPHA = "35%"       # the baseline while nothing plays


def palette(theme=THEME):
    """The gradient colors of the cava theme wallust writes, in order."""
    try:
        text = theme.read_text()
    except OSError:
        return []
    return re.findall(r"gradient_color_\d+\s*=\s*'([^']+)'", text)


def bar_count(conf=CONF, default=10):
    try:
        found = re.search(r"^\s*bars\s*=\s*(\d+)", conf.read_text(), re.M)
    except OSError:
        return default
    return int(found.group(1)) if found else default


def render(heights, colors):
    """Waybar's JSON for one frame. Every bar is drawn, zeros included: a
    module that changes width on silence shoves the rest of the bar around."""
    markup = ""
    for h in heights:
        glyph = GLYPHS[max(0, min(h, 7))]
        if colors:
            markup += f"<span color='{colors[h * (len(colors) - 1) // 7]}'>{glyph}</span>"
        else:
            markup += glyph
    if any(heights):
        return {"text": markup, "class": "active"}
    return {"text": f"<span alpha='{IDLE_ALPHA}'>{markup}</span>", "class": "idle"}


def parse(line):
    """cava's raw ascii frame: heights separated by spaces."""
    return [int(v) for v in line.split() if v.isdigit()]


class CavaWaybar(WaybarModule):
    def __init__(self, conf=CONF, theme=THEME):
        super().__init__()
        self.conf = conf
        self.colors = palette(theme)
        self.heights = [0] * bar_count(conf)

    def state(self):
        return render(self.heights, self.colors)

    def events(self):
        for line in lines(["cava", "-p", str(self.conf)]):
            heights = parse(line)
            if heights:
                self.heights = heights
                yield


if __name__ == "__main__":
    CavaWaybar().run()
