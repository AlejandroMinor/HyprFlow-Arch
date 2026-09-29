"""Desktop notifications through notify-send."""

import subprocess


def send(summary, body="", app="HyprFlow", urgency="normal", icon=None):
    command = ["notify-send", "-a", app, "-u", urgency]
    if icon:
        command += ["-i", icon]
    # "--" first: a summary like a device's name could start with "-", and
    # notify-send would read it as options and show nothing.
    subprocess.run([*command, "--", summary, *([body] if body else [])], stderr=subprocess.DEVNULL)
