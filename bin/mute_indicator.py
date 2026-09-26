#!/usr/bin/env python3
"""Mute indicator for the default output, for Waybar (continuous: no interval).

Prints the state once, then again only when PipeWire reports a change to a
sink or to the default device, instead of polling every second.
"""

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))
from waybar_module import WaybarModule, lines  # noqa: E402

SINK = "@DEFAULT_AUDIO_SINK@"


def wpctl(*args):
    return subprocess.run(["wpctl", *args], capture_output=True, text=True).stdout


def card_name(inspect_output):
    """The ALSA card name from `wpctl inspect`, e.g. "HD-Audio Generic"."""
    for line in inspect_output.splitlines():
        if "alsa.card_name" in line and '"' in line:
            return line.split('"')[1]
    return "Audio Device"


class MuteIndicator(WaybarModule):
    def state(self):
        if "[MUTED]" in wpctl("get-volume", SINK):
            return {"text": "󰖁", "class": "muted_active",
                    "tooltip": f"{card_name(wpctl('inspect', SINK))} is muted"}
        return {"text": "󰕾", "class": "", "tooltip": "Click to expand audio"}

    def events(self):
        # Volume changes fire sink events too; emit() skips unchanged states.
        for line in lines(["pactl", "subscribe"]):
            if "on sink " in line or "on server" in line:
                yield


if __name__ == "__main__":
    MuteIndicator().run()
