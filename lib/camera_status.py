#!/usr/bin/env python3
"""Camera-in-use indicator for Waybar (continuous: no interval).

Prints the state once, then again only when a /dev/video* device is opened or
closed (or one is plugged in), using the kernel's inotify events instead of
scanning every process every two seconds.
"""

import ctypes
import os
import re
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow.waybar import WaybarModule, libc  # noqa: E402

IN_OPEN = 0x00000020
IN_CLOSE_WRITE = 0x00000008
IN_CLOSE_NOWRITE = 0x00000010
IN_ATTRIB = 0x00000004
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_CLOEXEC = 0o2000000  # not inherited by anything this process starts
EVENT_HEADER = struct.Struct("iIII")

# The libc hyprflow.waybar already loaded, with the inotify calls typed.
libc.inotify_init1.argtypes, libc.inotify_init1.restype = [ctypes.c_int], ctypes.c_int
libc.inotify_add_watch.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
libc.inotify_add_watch.restype = ctypes.c_int


def video_devices():
    # video0, video1...: not /dev/video (a folder some setups have) or videoctl.
    return {f"/dev/{d}" for d in os.listdir("/dev") if re.fullmatch(r"video\d+", d)}


def check_camera():
    """Returns the video device some process holds open, or None."""
    devices = video_devices()
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        fd_dir = f"/proc/{pid}/fd"
        try:
            fds = os.listdir(fd_dir)
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            continue
        for fd in fds:
            try:
                target = os.readlink(f"{fd_dir}/{fd}")
            except OSError:
                continue
            if target in devices:
                return target
    return None


def camera_state():
    device = check_camera()
    if device:
        return {"text": "\uf03d ", "class": "active", "tooltip": f"Cámara en uso: {device}"}  # nf-fa-video_camera
    return {"text": "", "class": "inactive"}


def watch(fd):
    """Watches every video device, plus /dev for cameras plugged in later.

    Watching a device needs read access to it, and udev grants the user's
    access (the ACL) a moment after it creates the node, so a watch added on
    the create event fails. /dev also reports that permission change
    (IN_ATTRIB), which gets another try; adding a watch twice is harmless.
    """
    for path in video_devices():
        libc.inotify_add_watch(fd, path.encode(), IN_OPEN | IN_CLOSE_WRITE | IN_CLOSE_NOWRITE)
    libc.inotify_add_watch(fd, b"/dev", IN_CREATE | IN_DELETE | IN_ATTRIB)


def video_event(data):
    """True if a batch of inotify events says a video device came, went, or
    got its permissions (a camera plugged in or out). Opens and closes on a
    device already watched only need a fresh state, not new watches."""
    offset = 0
    while offset < len(data):
        _, mask, _, length = EVENT_HEADER.unpack_from(data, offset)
        name = data[offset + EVENT_HEADER.size: offset + EVENT_HEADER.size + length].rstrip(b"\0")
        if mask & (IN_CREATE | IN_DELETE | IN_ATTRIB) and name.startswith(b"video"):
            return True
        offset += EVENT_HEADER.size + length
    return False


class CameraStatus(WaybarModule):
    def state(self):
        return camera_state()

    def events(self):
        fd = libc.inotify_init1(IN_CLOEXEC)
        if fd < 0:
            sys.exit("inotify is not available")
        watch(fd)
        try:
            while True:
                if video_event(os.read(fd, 4096)):
                    watch(fd)  # new device nodes need their own watch
                yield
        finally:
            os.close(fd)


if __name__ == "__main__":
    CameraStatus().run()
