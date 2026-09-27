"""Where HyprFlow keeps its files, following the XDG base directories."""

import os
from pathlib import Path


def _xdg(variable, default):
    return Path(os.environ.get(variable) or Path.home() / default)


CONFIG = _xdg("XDG_CONFIG_HOME", ".config")
STATE = _xdg("XDG_STATE_HOME", ".local/state")
CACHE = _xdg("XDG_CACHE_HOME", ".cache")
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or "/tmp")

HYPRFLOW_CONFIG = CONFIG / "hyprflow"   # per machine, out of the repo (hooks)
HYPRFLOW_STATE = STATE / "hyprflow"     # survives reboots
HYPRFLOW_RUNTIME = RUNTIME              # gone at reboot
