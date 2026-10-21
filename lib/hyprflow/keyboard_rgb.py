"""The lights of the BY Tech gaming keyboard (USB 258a:0049, a Sinowealth
chip). OpenRGB does not know it; it is driven here through its own feature
reports, worked out by reading the keyboard while its Fn keys changed things.

The settings live in one 1032-byte block (feature report 6):

    0x15            the effect in use, 1..20
    0x26 + 2(n-1)   effect n: [colour] [speed << 4 | brightness]

Colour is an index into the keyboard's own palette (PALETTE), not RGB, so a
theme colour becomes the nearest one. Brightness goes 0..4; 0 is dark.

Reading asks for the block (report 5: 83 b6) and then fetches it; writing
sends it back with 03 in place of 83. Only this block is ever written: the
pages next to it hold the firmware.
"""

import colorsys
import fcntl
import os
import time
from pathlib import Path

VENDOR, PRODUCT = 0x258A, 0x0049
SYSFS = Path("/sys/class/hidraw")

READ, WRITE = 0x83, 0x03
PAGE = 0xB6
BLOCK = 1032
EFFECT = 0x15
TABLE = 0x26

MAX_BRIGHTNESS = 4
MULTICOLOUR = 7
PINKISH = (330, 355)  # hue degrees that go to purple (5), not red
OWN_COLOURS = (3, 15, 16)  # effects with their own colours: paint() skips them

# Index -> (name, hue in degrees, how a preview draws it); white has no hue.
PALETTE = {
    0: ("red", 0, "#FF0000"),
    1: ("yellow", 60, "#FFFF00"),
    2: ("green", 120, "#00FF00"),
    3: ("cyan", 180, "#00FFFF"),
    4: ("blue", 240, "#0000FF"),
    5: ("purple", 300, "#FF00FF"),
    6: ("white", None, "#FFFFFF"),
}

# As seen on the keyboard, in its own order (Fn cycles 1 -> 20 -> 1).
EFFECTS = (
    "All lit", "Breathing", "Spectrum", "Typed keys", "Rain",
    "Twinkle", "Ripple", "Fading sections", "Solid", "Snake",
    "Wave", "Off", "Center out", "Sweep", "Rainbow wave",
    "Rising rainbow", "Burst", "Collide", "Collide 2", "Ripple 2",
)


def _ioctl(nr, size):
    """HIDIOCSFEATURE (6) / HIDIOCGFEATURE (7) for a buffer of size bytes."""
    return (3 << 30) | (size << 16) | (ord("H") << 8) | nr


class Hidraw:
    """Feature reports on one hidraw node."""

    def __init__(self, path):
        self.fd = os.open(path, os.O_RDWR)

    def set_feature(self, data):
        fcntl.ioctl(self.fd, _ioctl(6, len(data)), bytearray(data))

    def get_feature(self, report, size):
        buf = bytearray(size)
        buf[0] = report
        fcntl.ioctl(self.fd, _ioctl(7, size), buf)
        return buf

    def close(self):
        os.close(self.fd)


def find(sysfs=SYSFS):
    """The keyboard's control node (/dev/hidrawN), or None when it is not
    plugged in. It has two: the control one is the one with report 6."""
    wanted = f"HID_ID=0003:{VENDOR:08X}:{PRODUCT:08X}"
    for node in sorted(sysfs.glob("hidraw*")):
        try:
            if wanted not in (node / "device" / "uevent").read_text():
                continue
            descriptor = (node / "device" / "report_descriptor").read_bytes()
        except OSError:
            continue
        if b"\x85\x06" in descriptor:  # Report ID 6
            return f"/dev/{node.name}"
    return None


def nearest(hex_colour):
    """The palette index closest to an RRGGBB colour: white for greys, else
    the nearest hue."""
    hex_colour = hex_colour.lstrip("#")
    r, g, b = (int(hex_colour[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hue, saturation, _ = colorsys.rgb_to_hsv(r, g, b)
    if saturation < 0.15:
        return 6
    degrees = hue * 360
    # Reds leaning to blue show pink on the case LEDs; the keyboard's light
    # purple looks closer than its red.
    if PINKISH[0] <= degrees < PINKISH[1]:
        return 5
    hues = {i: h for i, (_, h, _) in PALETTE.items() if h is not None}
    return min(hues, key=lambda i: min(abs(degrees - hues[i]), 360 - abs(degrees - hues[i])))


class Keyboard:
    """Read-modify-write of the settings block: every change reads it fresh,
    so whatever the Fn keys set in between is kept."""

    def __init__(self, device):
        self.device = device

    def read(self):
        # Right after a write the keyboard turns requests down for a moment.
        for attempt in range(5):
            try:
                self.device.set_feature([5, READ, PAGE, 0, 0, 0])
                block = self.device.get_feature(6, BLOCK)
                # Another page would be written back over this one.
                if block[1:3] != bytes([READ, PAGE]):
                    raise OSError(f"answered page {block[2]:02x}, not {PAGE:02x}")
                return block
            except OSError:
                if attempt == 4:
                    raise
                time.sleep(0.3)

    def write(self, block):
        block = bytearray(block)
        block[1] = WRITE
        self.device.set_feature(block)

    def effect(self):
        return self.read()[EFFECT]

    def set_effect(self, number):
        if not 1 <= number <= len(EFFECTS):
            raise ValueError(f"no effect {number}")
        block = self.read()
        block[EFFECT] = number
        self.write(block)

    def paint(self, colour=None, brightness=None):
        """Colour and/or brightness of every effect, each keeping its speed:
        an effect switched to later (the Fn keys) shows the theme too."""
        block = self.read()
        for n in range(1, len(EFFECTS) + 1):
            at = TABLE + 2 * (n - 1)
            if colour is not None and n not in OWN_COLOURS:
                block[at] = colour
            if brightness is not None:
                block[at + 1] = (block[at + 1] & 0xF0) | brightness
        self.write(block)

    def set_light(self, colour=None, brightness=None):
        """Colour (palette index) and/or brightness of the effect in use."""
        block = self.read()
        at = TABLE + 2 * (block[EFFECT] - 1)
        if colour is not None:
            block[at] = colour
        if brightness is not None:
            block[at + 1] = (block[at + 1] & 0xF0) | brightness
        self.write(block)
