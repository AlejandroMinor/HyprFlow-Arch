"""The level OSD (Osd.qml), or a notification without Quickshell. A value
under 0 draws no bar. Python side of common.sh's osd."""

import subprocess

from . import notify


def show(icon, title, caption="", value=0, app="HyprFlow"):
    """Show the OSD; the notification when Quickshell is not running. True
    when the panel took it."""
    if _push(icon, title, caption, value):
        return True
    notify.send(title, caption, app=app)
    return False


def quickshell_up():
    """True when the Quickshell config answers IPC (common.sh's quickshell_up)."""
    try:
        result = subprocess.run(["qs", "-c", "hyprflow", "ipc", "show"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return False
    return result.returncode == 0


def _push(icon, title, caption, value):
    try:
        result = subprocess.run(
            ["qs", "-c", "hyprflow", "ipc", "call", "osd", "level",
             icon, title, caption, str(value)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        return False
    return result.returncode == 0
