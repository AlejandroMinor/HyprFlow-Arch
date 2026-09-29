"""One copy at a time, for the long running helpers Hyprland starts at login:
a config reload runs their exec lines again, and a second copy must bow out."""

import fcntl
import sys

from . import paths


def single_instance(name):
    """Exits quietly if another copy of `name` already runs; else returns the
    lock, which the caller keeps for the life of the process."""
    lock = open(paths.HYPRFLOW_RUNTIME / f"{name}.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)
    return lock
