"""The current wallust palette, as the shell file wallust writes it
(colors-rofi-sh.conf: color0='#...' ... foreground=... background=...)."""

from . import paths

FILE = paths.CACHE / "wallust" / "colors" / "colors-rofi-sh.conf"


def load(path=FILE):
    """{name: '#rrggbb'}; empty when wallust has not written a palette yet."""
    colours = {}
    try:
        with open(path) as f:
            for line in f:
                key, _, value = line.strip().partition("=")
                if key:
                    colours[key] = value.strip("'\"")
    except OSError:
        pass
    return colours
