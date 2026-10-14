#!/usr/bin/env python3
"""Gives the headset its LED colour back each time it turns on.

OpenRGB only finds devices when its server starts, and the headset (the G733,
say) comes back on with its own colours, so every power on needs a rescan and
the colour again: rgb-sync.sh --rescan. The dongle stays plugged in, so no USB
event says the headset turned on, but the headset itself sends an unasked
HID++ notification when it turns on or off: that wakes this to ask
headsetcontrol, with a slow poll as the fallback. hyprland.lua starts it.
"""

import json
import os
import select
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from hyprflow.lock import single_instance  # noqa: E402

POLL = 60  # seconds: the fallback; the headset's own notifications come first
SETTLE = 1  # seconds after a notification before the headset answers
HIDRAW = Path("/sys/class/hidraw")
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


def headset_ids():
    """(vendor, product) of the headset headsetcontrol reaches, or None."""
    try:
        out = subprocess.run(["headsetcontrol", "-o", "json"],
                             capture_output=True, text=True, timeout=5).stdout
        headset = json.loads(out)["devices"][0]
        return int(headset["id_vendor"], 16), int(headset["id_product"], 16)
    except (OSError, subprocess.SubprocessError, ValueError, LookupError, TypeError):
        return None


def hidraws(vendor, product, root=HIDRAW):
    """The /dev/hidrawN nodes of the device with these USB ids."""
    wanted = f"HID_ID=0003:{vendor:08X}:{product:08X}"
    found = []
    for node in sorted(root.glob("hidraw*")):
        try:
            if wanted in (node / "device" / "uevent").read_text().splitlines():
                found.append(f"/dev/{node.name}")
        except OSError:
            pass
    return found


def notification(data):
    """An HID++ report the device sent unasked (software id 0), such as the
    battery notice of turning on or off. Replies to headsetcontrol, OpenRGB
    or battery-hub carry their own software id."""
    return len(data) >= 4 and data[0] in (0x10, 0x11) and data[3] & 0x0F == 0


def main():
    if not shutil.which("headsetcontrol"):
        return
    _lock = single_instance("headset-watch")
    watch = PowerWatch()
    fds = []
    last = 0.0
    while True:
        if not fds:
            ids = headset_ids()
            for path in hidraws(*ids) if ids else []:
                try:
                    fds.append(os.open(path, os.O_RDONLY))
                except OSError:
                    pass
        woke = False
        for fd in select.select(fds, [], [], POLL)[0]:
            try:
                woke = notification(os.read(fd, 64)) or woke
            except OSError:  # the dongle went away
                os.close(fd)
                fds.remove(fd)
        if woke:
            time.sleep(SETTLE)
        if woke or time.monotonic() - last >= POLL:
            watch.check()
            last = time.monotonic()


if __name__ == "__main__":
    main()
