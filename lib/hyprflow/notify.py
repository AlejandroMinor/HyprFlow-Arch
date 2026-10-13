"""Desktop notifications through notify-send.

send() is the one place notifications are built, so every script speaks the
same options. On top of what notify-send already does (app, urgency, icon) it
passes a timeout, a transient flag, the id to replace, a category and any
hints. Actions ([("key", "Label")]) become buttons in swaync; the command a
button runs lives in the swaync config, matched on the app name (see
dotconfig/swaync/config.json), so a notification carries a single action.
"""

import subprocess


def send(summary, body="", app="HyprFlow", urgency="normal", icon=None,
         timeout=None, transient=False, replace_id=None, category=None,
         actions=None, hints=None):
    """Show a desktop notification.

    timeout: milliseconds notify-send waits before hiding it (0: never).
    transient: do not keep it in the notification center.
    replace_id: update the notification with this id instead of stacking.
    category: the notification category (a script can match on it).
    actions: [(key, label)] buttons; also the default action when clicked.
    hints: {"key": value} extra hints (e.g. a synchronous id to merge).
    """
    command = ["notify-send", "-a", app, "-u", urgency]
    if icon:
        command += ["-i", icon]
    if category:
        command += ["-c", category]
    if timeout is not None:
        command += ["-t", str(timeout)]
    if transient:
        command += ["-e"]
    if replace_id is not None:
        command += ["-r", str(replace_id)]
    for key, value in (hints or {}).items():
        command += ["-h", f"{key}:{value}"]
    for key, label in actions or []:
        command += ["-A", f"{key}={label}"]
    # "--" first: a summary like a device's name could start with "-", and
    # notify-send would read it as options and show nothing.
    command += ["--", summary]
    if body:
        command += [body]
    # -A makes notify-send wait for the user; we never read that reply (swaync
    # runs the button itself), and a critical one never expires, so without a
    # timeout the caller -- a Waybar module among them -- would hang. Time to
    # hand the notification over is all it needs; killing it does not retract
    # what the daemon already has.
    try:
        subprocess.run(command, stderr=subprocess.DEVNULL, **({"timeout": 1} if actions else {}))
    except subprocess.TimeoutExpired:
        pass
