#!/usr/bin/env python3
"""Quick actions menu (Super+K): screens, game mode, lights, audio, notifications,
power profile, wallpaper, theme.

Each entry is a Command: its name, how to read its state (for the switches),
what to run and its section. A new action is one more entry in ACTIONS, tagged
with one of SECTIONS; an action whose program is missing (needs) is left out.

The menu is rofi (a bold heading row per section), or the Quickshell panel,
which reads `--json`, groups by section and runs its pick with `--run LABEL`.
"""

import json
import shutil
import subprocess
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import paths  # noqa: E402
from hyprflow.menu import RofiMenu  # noqa: E402

LIB = Path(__file__).resolve().parent
BIN = LIB.parent / "bin"


@dataclass(frozen=True)
class Action:
    icon: str
    label: str
    argv: list
    state: Callable[[], bool | str | None] | None = None  # on/off, or a word
    needs: str | None = None  # program that must be installed
    section: str = ""  # heading it is filed under; see SECTIONS

    def available(self):
        return self.needs is None or shutil.which(self.needs) is not None

    def state_word(self):
        state = self.state() if self.state else None
        if isinstance(state, bool):
            return "on" if state else "off"
        return state or ""

    def row(self):
        text = f"{self.icon}  {self.label}"
        if state := self.state_word():
            text += f"   <span alpha='55%'>{state}</span>"
        return text

    def as_dict(self):
        return {"icon": self.icon, "label": self.label,
                "state": self.state_word(), "section": self.section}

    def run(self):
        # Detached: game mode or a monitor change outlive this menu.
        subprocess.Popen([str(a) for a in self.argv], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)


# ── current states (None when they cannot be read) ────────────────────────

def mirror_on():
    try:
        import monitors
        profile = monitors.Profiles().get(monitors.signature(monitors.detect()))
    except (OSError, ValueError):
        return None
    return any("mirror" in entry for entry in profile or [])


def solo_on():
    try:
        import monitors
    except (OSError, ValueError):
        return None
    return monitors.read_solo() is not None


def game_mode_on():
    return (paths.HYPRFLOW_STATE / "game-mode").exists()


def lights_on():
    return not (paths.CACHE / "wallust" / "led-off").exists()


def output(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=2).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def dnd_on():
    return {"true": True, "false": False}.get(output(["swaync-client", "-D"]))


def mic_on():
    volume = output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"])
    return "MUTED" not in volume if volume else None


def power_profile():
    return output(["powerprofilesctl", "get"]) or None


def current_layout():
    return output([LIB / "layout-picker.py", "--state"]) or None


# In the order they show; an action with none goes last, without a heading.
SECTIONS = ("Screens", "Audio", "System", "Appearance")

ACTIONS = [
    Action("󰍺", "Mirror screens", [BIN / "monitors.sh", "mirror", "toggle"], mirror_on, section="Screens"),
    Action("󰍹", "Only the main screen", [BIN / "monitors.sh", "solo", "toggle"], solo_on, section="Screens"),
    Action("󰓃", "Audio output", [LIB / "sink-switch.py", "--toggle"], needs="wpctl", section="Audio"),
    Action("󰍬", "Microphone", [LIB / "volume.sh", "mic-mute"], mic_on, needs="wpctl", section="Audio"),
    Action("󰊴", "Game mode", [BIN / "game-mode.sh", "toggle"], game_mode_on, section="System"),
    Action("󰂛", "Do not disturb", ["swaync-client", "-d"], dnd_on, needs="swaync-client", section="System"),
    Action("󰓅", "Power profile", [LIB / "power-profile.sh"], power_profile, needs="powerprofilesctl", section="System"),
    Action("󰌌", "Keyboard layout", [LIB / "layout-picker.py"], current_layout, needs="hyprctl", section="System"),
    Action("󰌵", "Lights", [BIN / "rgb-sync.sh", "--toggle"], lights_on, section="Appearance"),
    Action("󰸉", "Random wallpaper", ["waypaper", "--random"], section="Appearance"),
    Action("󰏘", "Theme", ["kitty", "--class", "kitty-theme-picker", "-e", BIN / "theme-picker.sh"], section="Appearance"),
]


def ordered(actions):
    """By section, in SECTIONS order; stable, so ACTIONS keeps its order within
    a section. An action with no (or an unknown) section goes last."""
    rank = {name: i for i, name in enumerate(SECTIONS)}
    return sorted(actions, key=lambda a: rank.get(a.section, len(SECTIONS)))


def grouped(actions):
    """Rofi wants a flat list: a bold heading row before each section, then its
    actions. Returns the rows and what each row index maps to (None: a heading,
    so picking it runs nothing)."""
    rows, targets, current = [], [], None
    for action in actions:
        if action.section and action.section != current:
            current = action.section
            rows.append(f"<b>{current}</b>")
            targets.append(None)
        rows.append(action.row())
        targets.append(action)
    return rows, targets


def main(menu=None, actions=ACTIONS, args=()):
    # Composition root: the menu comes in, so the tests pass a fake one.
    actions = ordered([a for a in actions if a.available()])
    if args[:1] == ["--json"]:
        print(json.dumps([a.as_dict() for a in actions], ensure_ascii=False))
        return 0
    if args[:1] == ["--run"]:
        action = next((a for a in actions if args[1:2] == [a.label]), None)
        if action is None:
            return 1
        action.run()
        return 0
    menu = menu or RofiMenu(width=520)
    rows, targets = grouped(actions)
    picked = menu.choose("Quick actions", rows)
    if picked is not None and 0 <= picked < len(targets) and targets[picked] is not None:
        targets[picked].run()
    return 0


if __name__ == "__main__":
    sys.exit(main(args=sys.argv[1:]))
