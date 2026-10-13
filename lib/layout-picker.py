#!/usr/bin/env python3
"""Pick the active keyboard layout, from the list declared in hyprland.lua.

The options come from Hyprland's input:kb_layout (es,us): picking one moves
it to the front, where it becomes the active layout, and keeps the rest as
fallbacks. Click, or the arrow keys plus Enter, pick one.

    layout-picker.py             the picker (Super+K > Keyboard layout)
    layout-picker.py --state     print the active layout, nothing else
    layout-picker.py --set es    apply directly (no menu)

The choice is runtime only, like the power profile: install.sh config brings
hyprland.lua's order back.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import hyprland, osd  # noqa: E402
from hyprflow.menu import RofiMenu  # noqa: E402

GLYPH = "\U000F030C"  # Nerd Font: keyboard


def layouts():
    """The declared layouts, in order; the first one is the active one.
    Empty when Hyprland cannot be asked."""
    try:
        declared = hyprland.query("getoption", "input:kb_layout").get("str", "") or ""
    except hyprland.HyprlandError:
        return []
    return [k for k in (k.strip() for k in declared.split(",")) if k]


def current():
    """The active layout (the first of the declared list), or None."""
    found = layouts()
    return found[0] if found else None


def switch(layout):
    """Make LAYOUT the active one (first in input:kb_layout). True when it
    was declared in hyprland.lua and Hyprland took it."""
    found = layouts()
    if layout not in found:
        return False
    reordered = [layout] + [k for k in found if k != layout]
    try:
        hyprland.eval_lua(f'hl.config({{ input = {{ kb_layout = "{",".join(reordered)}" }} }})')
    except hyprland.HyprlandError:
        return False
    if layouts() != reordered:
        return False
    osd.show(GLYPH, "Keyboard layout", layout, -1)
    return True


def main(argv, menu=None):
    if argv[:1] == ["--state"]:
        print(current() or "")
        return 0
    if argv[:1] == ["--set"]:
        return 0 if switch(argv[1]) else 1
    found = layouts()
    if not found:
        print("no keyboard layouts declared (input:kb_layout)", file=sys.stderr)
        return 1
    active = current()
    rows = [f"<b>{k}</b>   <span alpha='55%'>(active)</span>" if k == active else k
            for k in found]
    menu = menu or RofiMenu(width=520)
    picked = menu.choose("Keyboard layout", rows)
    if picked is None or not 0 <= picked < len(found):
        return 0
    return 0 if switch(found[picked]) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))