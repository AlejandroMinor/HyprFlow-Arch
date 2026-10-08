#!/usr/bin/env python3
"""Gives the headset its LED colour back each time it turns on.

OpenRGB only finds devices when its server starts, and the headset (the G733,
say) comes back on with its own colours, so every power on needs a rescan and
the colour again: rgb-sync.sh --rescan. The dongle stays plugged in, so no USB
event says the headset turned on; this asks headsetcontrol every POLL seconds.
hyprland.lua starts it.
"""

import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from hyprflow.lock import single_instance  # noqa: E402

POLL = 30  # seconds
RGB_SYNC = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "bin", "rgb-sync.sh"))


def headset_on():
    """Whether headsetcontrol reaches a headset. Its exit code is 0 even with
    the headset off, so the battery level says it: -1 or missing when off."""
    try:
        out = subprocess.run(["headsetcontrol", "-b", "-o", "json"],
                             capture_output=True, text=True, timeout=5).stdout
        data = json.loads(out)
    except (OSError, subprocess.SubprocessError, ValueError):
        return False
    headsets = data.get("devices") if isinstance(data, dict) else None
    for headset in headsets if isinstance(headsets, list) else []:
        battery = headset.get("battery") if isinstance(headset, dict) else None
        level = battery.get("level") if isinstance(battery, dict) else None
        if isinstance(level, int) and level >= 0:
            return True
    return False


def recolour():
    try:
        subprocess.Popen([RGB_SYNC, "--rescan"], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


class PowerWatch:
    """Calls powered_on() each time is_on() goes from off to on. On already at
    the first look does not count: OpenRGB found it when it started."""

    def __init__(self, is_on=headset_on, powered_on=recolour):
        self.is_on = is_on
        self.powered_on = powered_on
        self.was_on = None

    def check(self):
        on = self.is_on()
        if self.was_on is False and on:
            self.powered_on()
        self.was_on = on


def main():
    if not shutil.which("headsetcontrol"):
        return
    _lock = single_instance("headset-watch")
    watch = PowerWatch()
    while True:
        watch.check()
        time.sleep(POLL)


if __name__ == "__main__":
    main()
