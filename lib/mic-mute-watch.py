#!/usr/bin/env python3
"""Mirrors a headset's own mic mute button onto its Pipewire microphone, so
the bar and the OSD show it. hyprland.lua starts it.

Any USB device whose HID descriptor has the standard Phone Mute control
(Telephony page) counts. The button only says "toggled", never the state, so
each press toggles the device's own Pipewire source (matched on its vendor
and product ids). Muting from the PC as well can leave the two out of step;
one more press of either puts them back.
"""

import json
import os
import select
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from hyprflow.lock import single_instance  # noqa: E402

HIDRAW = Path("/sys/class/hidraw")
TELEPHONY, PHONE_MUTE = 0x0B, 0x2F
INPUT, COLLECTION, END_COLLECTION = 0x80, 0xA0, 0xC0
RESCAN = 10  # seconds between looks for new devices


def mute_report_id(descriptor):
    """The report id that carries Phone Mute in a HID report descriptor, or
    None. A short item parser: usage page and report id are global, usages
    local to the next main item."""
    page = report = None
    usages = []
    i = 0
    while i < len(descriptor):
        prefix = descriptor[i]
        size = (0, 1, 2, 4)[prefix & 3]
        value = int.from_bytes(descriptor[i + 1:i + 1 + size], "little")
        tag = prefix & 0xFC
        i += 1 + size
        if tag == 0x04:
            page = value
        elif tag == 0x84:
            report = value
        elif tag == 0x08:
            # A 4 byte usage carries its own page in the high half.
            usages.append((value >> 16, value & 0xFFFF) if size == 4 else (page, value))
        elif tag in (INPUT, COLLECTION, END_COLLECTION):
            if tag == INPUT and (TELEPHONY, PHONE_MUTE) in usages:
                return report
            usages = []
    return None


@dataclass
class MuteButton:
    hidraw: str     # /dev/hidrawN
    vendor: int
    product: int
    report: int     # the report id a press arrives with


def find_buttons(root=HIDRAW):
    buttons = []
    for node in sorted(root.glob("hidraw*")):
        try:
            report = mute_report_id((node / "device" / "report_descriptor").read_bytes())
            uevent = (node / "device" / "uevent").read_text()
        except OSError:
            continue
        hid_id = next((line.split("=", 1)[1] for line in uevent.splitlines()
                       if line.startswith("HID_ID=")), "")
        parts = hid_id.split(":")
        if report is None or len(parts) != 3:
            continue
        buttons.append(MuteButton(f"/dev/{node.name}", int(parts[1], 16), int(parts[2], 16), report))
    return buttons


def source_of(vendor, product, dump=None):
    """The Pipewire source node of the audio device with these USB ids."""
    if dump is None:
        try:
            dump = json.loads(subprocess.run(["pw-dump"], capture_output=True,
                                             text=True, timeout=5).stdout)
        except (OSError, subprocess.SubprocessError, ValueError):
            return None
    props = {o["id"]: (o.get("info") or {}).get("props") or {} for o in dump}
    devices = {i for i, p in props.items()
               if str(p.get("device.vendor.id", "")).lower() == f"{vendor:#06x}"
               and str(p.get("device.product.id", "")).lower() == f"{product:#06x}"}
    return next((i for i, p in props.items()
                 if p.get("media.class") == "Audio/Source" and p.get("device.id") in devices), None)


def toggle(button):
    source = source_of(button.vendor, button.product)
    if source is not None:
        subprocess.run(["wpctl", "set-mute", str(source), "toggle"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pressed(button, data):
    """A report from the button's device is a press when it carries its id."""
    return bool(data) and data[0] == button.report


def main():
    if not (shutil.which("wpctl") and shutil.which("pw-dump")):
        return
    _lock = single_instance("mic-mute-watch")
    open_ = {}  # fd -> MuteButton
    while True:
        known = {b.hidraw for b in open_.values()}
        for button in find_buttons():
            if button.hidraw not in known:
                try:
                    open_[os.open(button.hidraw, os.O_RDONLY)] = button
                except OSError:
                    pass
        # Waits for a press; every RESCAN seconds looks for new devices.
        for fd in select.select(list(open_), [], [], RESCAN)[0]:
            try:
                data = os.read(fd, 64)
            except OSError:  # unplugged
                os.close(fd)
                del open_[fd]
                continue
            if pressed(open_[fd], data):
                toggle(open_[fd])


if __name__ == "__main__":
    main()
