"""Asking the user through a menu (Strategy). Scripts speak to Menu; RofiMenu
is the one in use, on the hyprflow list theme. Another (a GTK one) would slot
in without touching the scripts."""

import subprocess
from dataclasses import dataclass
from typing import Protocol

from . import paths

THEME = paths.CONFIG / "rofi" / "hyprflow" / "list.rasi"
TIMEOUT = 300  # seconds; a menu left open longer counts as dismissed


@dataclass
class Choice:
    index: int
    delete: bool = False  # Alt+D rather than Enter


class Menu(Protocol):
    def choose(self, prompt: str, rows: list[str], hint: str = "") -> int | None:
        """The index of the chosen row, or None when dismissed."""

    def pick(self, prompt: str, rows: list[str], hint: str) -> Choice | None:
        """A chosen row that can also be deleted (Alt+D), or None."""

    def ask(self, prompt: str, options: list[str], hint: str = "") -> str | None:
        """Typed text or a chosen option, or None when dismissed."""


class RofiMenu:
    """Menu on rofi, with the hyprflow list theme."""

    def __init__(self, width=820):
        self.width = width

    def run(self, prompt, rows, hint="", extra=()):
        cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-theme", str(THEME),
               "-theme-str", f"window {{ width: {self.width}px; }} "
                             f"listview {{ lines: {min(max(len(rows), 1), 8)}; }}"]
        if hint:
            cmd += ["-mesg", hint]
        try:
            # A stuck rofi keeps its keyboard grab: give up on it eventually,
            # as if the menu had been dismissed.
            result = subprocess.run([*cmd, *extra], input="\n".join(rows), text=True,
                                    capture_output=True, timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            return 1, ""
        return result.returncode, result.stdout.strip()

    def choose(self, prompt, rows, hint=""):
        code, index = self.run(prompt, rows, hint, ["-markup-rows", "-format", "i"])
        return int(index) if code == 0 and index.isdigit() else None

    def pick(self, prompt, rows, hint):
        code, index = self.run(prompt, rows, hint,
                               ["-markup-rows", "-format", "i", "-kb-custom-1", "Alt+d"])
        if code not in (0, 10) or not index.isdigit():
            return None
        return Choice(int(index), delete=code == 10)

    def ask(self, prompt, options, hint=""):
        code, text = self.run(prompt, options, hint)
        return text if code == 0 and text else None
