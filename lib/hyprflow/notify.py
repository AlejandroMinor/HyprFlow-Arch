"""Desktop notifications through notify-send."""

import subprocess


def send(summary, body="", app="HyprFlow", urgency="normal", icon=None):
    command = ["notify-send", "-a", app, "-u", urgency]
    if icon:
        command += ["-i", icon]
    subprocess.run([*command, summary, *([body] if body else [])], stderr=subprocess.DEVNULL)
