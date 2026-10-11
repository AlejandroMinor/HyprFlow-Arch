#!/usr/bin/env python3
"""Quick actions menu (Super+K): screens, game mode, lights, audio, notifications,
power profile, wallpaper, theme.

Each entry is a Command: what it is called, how to read its current state
(for the ones that switch something on and off) and what to run. The menu only
lists them and runs the one picked, so a new action is one more entry in
ACTIONS; nothing else changes. An action whose program is missing (needs) is
left out of the menu.
"""

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

    def available(self):
        return self.needs is None or shutil.which(self.needs) is not None

    def row(self):
        text = f"{self.icon}  {self.label}"
        state = self.state() if self.state else None
        if isinstance(state, bool):
            state = "on" if state else "off"
        if state:
            text += f"   <span alpha='55%'>{state}</span>"
        return text

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


ACTIONS = [
    Action("󰍺", "Mirror screens", [BIN / "monitors.sh", "mirror", "toggle"], mirror_on),
    Action("󰍹", "Only the main screen", [BIN / "monitors.sh", "solo", "toggle"], solo_on),
    Action("󰊴", "Game mode", [BIN / "game-mode.sh", "toggle"], game_mode_on),
    Action("󰌵", "Lights", [BIN / "rgb-sync.sh", "--toggle"], lights_on),
    Action("󰓃", "Audio output", ["kitty", "--class", "kitty-sinkswitch", "-e",
                                 "sinkswitch", "-sync", "-notify-hypr", "-nick"], needs="sinkswitch"),
    Action("󰍬", "Microphone", [LIB / "volume.sh", "mic-mute"], mic_on, needs="wpctl"),
    Action("󰂛", "Do not disturb", ["swaync-client", "-d"], dnd_on, needs="swaync-client"),
    Action("󰓅", "Power profile", [LIB / "power-profile.sh"], power_profile, needs="powerprofilesctl"),
    Action("󰸉", "Random wallpaper", ["waypaper", "--random"]),
    Action("󰏘", "Theme", ["kitty", "--class", "kitty-theme-picker", "-e", BIN / "theme-picker.sh"]),
]


def main(menu=None, actions=ACTIONS):
    # Composition root: the menu comes in, so the tests pass a fake one.
    menu = menu or RofiMenu(width=520)
    actions = [a for a in actions if a.available()]
    picked = menu.choose("Quick actions", [a.row() for a in actions])
    if picked is not None and 0 <= picked < len(actions):
        actions[picked].run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
