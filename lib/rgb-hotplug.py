#!/usr/bin/env python3
"""Rescans OpenRGB when a USB device is plugged in, so a new mouse or
keyboard takes the LED colour (or stays off) like the rest: the OpenRGB
server only detects devices when it starts. hyprland.lua starts it.

The headset is headset-watch.py's: its dongle stays plugged in, so turning it
on brings no USB event.
"""

import os
import shutil
import subprocess
import sys
import threading

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from hyprflow.lock import single_instance  # noqa: E402

SETTLE = 3  # seconds: one device brings several events, one rescan for all
RGB_SYNC = os.path.normpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "bin", "rgb-sync.sh"))
MONITOR = ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device"]


def rescan():
    try:
        subprocess.Popen([RGB_SYNC, "--rescan"], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


class Hotplug:
    """Calls rescan() SETTLE seconds after the last device added. Reads
    udevadm monitor lines: "UDEV  [123.4] add  /devices/... (usb)"."""

    def __init__(self, rescan=rescan, timer=threading.Timer):
        self.rescan = rescan
        self.timer = timer
        self.pending = None

    def line(self, line):
        fields = line.split()
        if len(fields) < 3 or fields[0] != "UDEV" or fields[2] != "add":
            return
        if self.pending:
            self.pending.cancel()
        self.pending = self.timer(SETTLE, self.rescan)
        self.pending.daemon = True
        self.pending.start()


def main():
    if not (shutil.which("udevadm") and shutil.which("openrgb")):
        return
    _lock = single_instance("rgb-hotplug")
    watch = Hotplug()
    monitor = subprocess.Popen(MONITOR, stdout=subprocess.PIPE, text=True)
    for line in monitor.stdout:
        watch.line(line)


if __name__ == "__main__":
    main()
