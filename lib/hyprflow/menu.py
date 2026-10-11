"""Asking the user through a menu (Strategy). Scripts speak to Menu: RofiMenu
on the hyprflow list theme, or QuickshellMenu, which moves the confirmations to
the Quickshell panel and leaves the rest on rofi."""

import os
import select
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
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

    def confirm(self, prompt: str, options: list[str]) -> str | None:
        """One of a few options (the safe one first), or None when dismissed."""


class RofiMenu:
    """Menu on rofi, with the hyprflow list theme."""

    def __init__(self, width=820):
        self.width = width

    def run(self, prompt, rows, hint="", extra=(), width=None):
        cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-theme", str(THEME),
               "-theme-str", f"window {{ width: {width or self.width}px; }} "
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

    def confirm(self, prompt, options):
        # A narrow box: two options do not want the width of a list.
        code, text = self.run(prompt, options, width=400)
        return text if code == 0 and text else None


class QuickshellMenu(RofiMenu):
    """Confirmations on the Quickshell panel (Confirm.qml); lists, typing and
    everything while Quickshell is not running stay on rofi."""

    def confirm(self, prompt, options):
        with tempfile.TemporaryDirectory() as tmp:
            reply = Path(tmp) / "reply"
            os.mkfifo(reply)
            # Read-write: opening never blocks, select() waits for the answer.
            fd = os.open(reply, os.O_RDWR)
            try:
                try:
                    ipc = subprocess.run(["qs", "-c", "hyprflow", "ipc", "call", "confirm", "ask",
                                          prompt, "\n".join(options), str(reply)],
                                         capture_output=True, timeout=5)
                except (OSError, subprocess.TimeoutExpired):
                    ipc = None
                if ipc is None or ipc.returncode != 0:  # 255: Quickshell not running
                    return super().confirm(prompt, options)
                ready, _, _ = select.select([fd], [], [], TIMEOUT)
                answer = os.read(fd, 4096).decode().strip() if ready else ""
            finally:
                os.close(fd)
        return answer or None
