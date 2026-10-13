#!/usr/bin/env python3
"""Shows the level OSD for changes no key of ours reports: play/pause
(playerctl), Do Not Disturb (swaync's dconf key) and Caps/Num Lock (LEDs).
Started by hyprland.lua."""

import os
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from hyprflow import osd                        # noqa: E402
from hyprflow.lock import single_instance       # noqa: E402

LEDS = Path("/sys/class/leds")
POLL = 0.3   # seconds between Caps/Num Lock checks

# Nerd Font (Material Design) glyphs.
GLYPH = {
    "play": "\U000F040A", "pause": "\U000F03E4",
    "bell": "\U000F009A", "bell_off": "\U000F009B",
    "caps": "\U000F0A9B", "numeric": "\U000F03A0",
}

MEDIA_FORMAT = "{{playerName}}\t{{status}}\t{{mpris:length}}\t{{title}}\t{{artist}}"


class Media:
    """Play and pause only; skips are media.sh's. Tracked per player: the
    first line of each is its starting state, not shown. A player with no
    length (a browser tab's notification sound) is ignored."""

    def __init__(self, emit=None):
        self.emit = emit or osd.show
        self.status = {}  # player -> last status

    def line(self, line):
        player, status, length, title, artist = (
            line.rstrip("\n").split("\t") + [""] * 4)[:5]
        if not length or status not in ("Playing", "Paused"):
            # Stopped, closed or no length: forget it.
            self.status.pop(player, None)
            return
        was = self.status.get(player)
        if was is not None and status != was:
            glyph = GLYPH["pause"] if status == "Paused" else GLYPH["play"]
            self.emit(glyph, title or "Media", artist, -1)
        self.status[player] = status


class Dnd:
    """dconf watch output: only the true/false lines count."""

    def __init__(self, emit=None):
        self.emit = emit or osd.show

    def line(self, line):
        value = line.strip()
        if value not in ("true", "false"):
            return
        on = value == "true"
        self.emit(GLYPH["bell_off"] if on else GLYPH["bell"],
                  "Do not disturb", "On" if on else "Off", -1)


class Locks:
    """Shows the lock that changed; the first read is the starting state."""

    def __init__(self, read, emit=None):
        self.read = read
        self.emit = emit or osd.show
        self.was = None

    def check(self):
        caps, num = self.read()
        if self.was is not None:
            if caps != self.was[0]:
                self.emit(GLYPH["caps"], "Caps Lock", "On" if caps else "Off", -1)
            if num != self.was[1]:
                self.emit(GLYPH["numeric"], "Num Lock", "On" if num else "Off", -1)
        self.was = (caps, num)


def led_on(name):
    """Whether any keyboard's `name` LED is lit."""
    for path in LEDS.glob(f"*{name}*/brightness"):
        try:
            if path.read_text().strip() == "1":
                return True
        except OSError:
            pass
    return False


def read_locks():
    return led_on("capslock"), led_on("numlock")


def follow(argv):
    """Lines from a long-running command, restarted if it exits."""
    while True:
        try:
            process = subprocess.Popen(argv, stdout=subprocess.PIPE, text=True)
        except OSError:
            time.sleep(5)
            continue
        for line in process.stdout:
            yield line
        time.sleep(2)


def stream(carrier, argv):
    for line in follow(argv):
        carrier.line(line)


def main():
    _lock = single_instance("osd-watch")
    media, dnd, locks = Media(), Dnd(), Locks(read_locks)

    if shutil.which("playerctl"):
        threading.Thread(target=stream, args=(
            media, ["playerctl", "metadata", "--follow", "--format", MEDIA_FORMAT]),
            daemon=True).start()
    if shutil.which("dconf"):
        threading.Thread(target=stream, args=(
            dnd, ["dconf", "watch", "/org/erikreider/swaync/dnd-state"]),
            daemon=True).start()

    while True:
        locks.check()
        time.sleep(POLL)


if __name__ == "__main__":
    main()
