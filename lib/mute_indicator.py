#!/usr/bin/env python3
"""Audio status for Waybar (continuous: no interval): the default output and
the default microphone, at a glance.

    󰕾          output on, microphone on
    󰖁          output muted
    󰕾 󰍭       microphone muted: the badge stays until it is unmuted

The tooltip names both devices with their volume. It is the always visible
trigger of the audio drawer, so it is the one place that has to show a muted
microphone before you talk into a call for five minutes.

Prints the state once, then again only when PipeWire reports a change to a
device or to the defaults, instead of polling.
"""

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from waybar_module import WaybarModule, lines  # noqa: E402

SINK = "@DEFAULT_AUDIO_SINK@"
SOURCE = "@DEFAULT_AUDIO_SOURCE@"

SPEAKER, SPEAKER_MUTED, MIC_MUTED = "󰕾", "󰖁", "󰍭"


def wpctl(*args):
    return subprocess.run(["wpctl", *args], capture_output=True, text=True).stdout


def card_name(inspect_output):
    """The device's short name from `wpctl inspect`: its nick ("G733 Gaming
    Headset"), else the ALSA card name ("HD-Audio Generic")."""
    for key in ("node.nick", "alsa.card_name"):
        found = re.search(rf'{re.escape(key)} = "([^"]+)"', inspect_output)
        if found:
            return found.group(1)
    return "Audio Device"


def volume(get_volume_output):
    """(percent, muted) from `wpctl get-volume`, or None when there is no
    such device (no microphone plugged in)."""
    found = re.search(r"Volume:\s*([\d.]+)", get_volume_output)
    if not found:
        return None
    return round(float(found.group(1)) * 100), "[MUTED]" in get_volume_output


def describe(role, name, level):
    percent, muted = level
    return f"{role}: {name}  {percent}%" + ("  (muted)" if muted else "")


class MuteIndicator(WaybarModule):
    def state(self):
        out = volume(wpctl("get-volume", SINK)) or (0, False)
        mic = volume(wpctl("get-volume", SOURCE))
        out_muted = out[1]
        mic_muted = bool(mic and mic[1])

        text = SPEAKER_MUTED if out_muted else SPEAKER
        if mic_muted:
            text += f" {MIC_MUTED}"
        classes = [c for c, on in (("muted_active", out_muted), ("mic-muted", mic_muted)) if on]

        tooltip = [describe("Output", card_name(wpctl("inspect", SINK)), out)]
        if mic:
            tooltip.append(describe("Microphone", card_name(wpctl("inspect", SOURCE)), mic))
        tooltip.append("Click to expand audio")
        return {"text": text, "class": classes, "tooltip": "\n".join(tooltip)}

    def events(self):
        # Volume changes fire device events too; emit() skips unchanged states.
        for line in lines(["pactl", "subscribe"]):
            if "on sink " in line or "on source " in line or "on server" in line:
                yield


if __name__ == "__main__":
    MuteIndicator().run()
