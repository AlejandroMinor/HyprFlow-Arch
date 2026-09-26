#!/usr/bin/env python3
"""Saves the open windows as a named layout and brings them back later.

    session-manager.py save      ask for a name (existing ones listed, to overwrite)
    session-manager.py logout    save as the last session, then leave Hyprland
    session-manager.py load      pick a layout and reopen its windows

A layout is a JSON list in ~/.config/hypr/templates/, one entry per window:
the command that started it, its workspace, and for floating windows where
it sat on which monitor. Nothing reopens by itself at login; the last session
waits in the load menu until you want it.

Layout: the pure parts (what to save, how to describe a layout, where a
window goes back to) are functions of their inputs. Layouts is a Repository,
the only code that knows layouts are JSON files. Menu is a Strategy for asking
the user, RofiMenu today (a GTK one would slot in without touching the rest),
and Desktop adapts hyprctl. SessionManager runs save, logout and load on top
of them, so each flow is tested with fakes.
"""

import html
import json
import os
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

TEMPLATES = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "hypr" / "templates"
LAST = "default"                      # what logout writes; shown as "Last session"
IGNORED = {"waybar", "rofi", "swaync", ""}
THEME = Path.home() / ".config" / "rofi" / "hyprflow" / "list.rasi"
WAIT = 5.0                            # seconds a relaunched app gets to show its window


# ── pure ──────────────────────────────────────────────────────────────────

def snapshot(clients, monitors, command_of):
    """The layout entries for the windows in `clients`, from hyprctl's JSON.
    command_of(pid) gives the argv that started a window, or None. One entry
    per process: an app with several windows (VS Code) is relaunched once."""
    by_id = {m["id"]: m for m in monitors}
    entries, seen = [], set()
    for c in clients:
        if c["class"] in IGNORED or c["pid"] in seen:
            continue
        argv = command_of(c["pid"])
        if not argv:
            continue
        seen.add(c["pid"])
        mon = by_id.get(c.get("monitor"), {"name": "", "x": 0, "y": 0})
        entries.append({
            "workspace": c["workspace"]["id"],
            "command": argv,
            "class": c["class"],
            "initialClass": c.get("initialClass") or c["class"],
            "floating": c.get("floating", False),
            "monitor": mon["name"],
            "at": [c["at"][0] - mon["x"], c["at"][1] - mon["y"]],
            "size": c.get("size", [800, 600]),
        })
    return entries


def ago(seconds):
    if seconds < 90:
        return "just now"
    if seconds < 5400:
        return f"{round(seconds / 60)} min ago"
    if seconds < 129600:
        return f"{round(seconds / 3600)} h ago"
    return f"{round(seconds / 86400)} days ago"


def describe(entries, age):
    """One line for the load menu: how many windows, where, which apps."""
    apps = list(dict.fromkeys(e["class"] for e in entries))
    workspaces = sorted({e["workspace"] for e in entries if e["workspace"] > 0})
    parts = [f"{len(entries)} window{'s' if len(entries) != 1 else ''}"]
    if workspaces:
        parts.append(f"ws {', '.join(map(str, workspaces))}")
    if apps:
        parts.append(", ".join(apps[:3]) + (" …" if len(apps) > 3 else ""))
    parts.append(ago(age))
    return "  ·  ".join(parts)


def title(name):
    return "Last session" if name == LAST else name


def launch_argv(command):
    """Layouts store argv lists; older ones a joined string, run by a shell."""
    if isinstance(command, list):
        return command
    return ["bash", "-c", command]


def placement(entry, monitors, address):
    """The hyprctl dispatches that put a relaunched window back where it was.
    Floating positions are relative to their monitor, found again by name,
    or the first monitor if that one is not connected now."""
    ws = entry["workspace"]
    target = "special:magic" if ws < 0 else ws
    win = f"window='address:{address}'"
    calls = [f"hl.dsp.window.move({{workspace='{target}', follow=false, {win}}})"]
    if entry.get("floating"):
        mon = next((m for m in monitors if m["name"] == entry.get("monitor")), monitors[0] if monitors else None)
        x = entry["at"][0] + (mon["x"] if mon else 0)
        y = entry["at"][1] + (mon["y"] if mon else 0)
        w, h = entry["size"]
        calls += [f"hl.dsp.window.float({{action='enable', {win}}})",
                  f"hl.dsp.window.move({{x={x}, y={y}, {win}}})",
                  f"hl.dsp.window.resize({{x={w}, y={h}, {win}}})"]
    return calls


# ── storage (Repository) ──────────────────────────────────────────────────

class Layouts:
    """Saved layouts. The rest of the code asks for them by name and never
    touches the JSON files."""

    def __init__(self, folder=TEMPLATES, clock=time.time):
        self.folder = Path(folder)
        self.clock = clock

    def path(self, name):
        return self.folder / f"{name}.json"

    def all(self):
        """(name, entries, age in seconds), newest first; unreadable files
        are skipped."""
        now, found = self.clock(), []
        for path in self.folder.glob("*.json"):
            try:
                entries = json.loads(path.read_text())
            except (OSError, ValueError):
                continue
            found.append((path.stem, entries, now - path.stat().st_mtime))
        return sorted(found, key=lambda item: item[2])

    def names(self):
        return [name for name, _, _ in self.all()]

    def exists(self, name):
        return self.path(name).exists()

    def save(self, name, entries):
        self.folder.mkdir(parents=True, exist_ok=True)
        self.path(name).write_text(json.dumps(entries, indent=4))

    def delete(self, name):
        self.path(name).unlink(missing_ok=True)


# ── asking the user (Strategy) ────────────────────────────────────────────

@dataclass
class Choice:
    index: int
    delete: bool = False  # Alt+D rather than Enter


class Menu(Protocol):
    def pick(self, prompt: str, rows: list[str], hint: str) -> Choice | None:
        """A row from a list of layouts, or None when dismissed."""

    def ask(self, prompt: str, options: list[str], hint: str = "") -> str | None:
        """Typed text or a chosen option, or None when dismissed."""


class RofiMenu:
    """Menu on rofi, with the hyprflow list theme."""

    def run(self, prompt, rows, hint="", extra=()):
        cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-theme", str(THEME),
               "-theme-str", f"window {{ width: 820px; }} listview {{ lines: {min(max(len(rows), 1), 8)}; }}"]
        if hint:
            cmd += ["-mesg", hint]
        result = subprocess.run([*cmd, *extra], input="\n".join(rows), text=True, capture_output=True)
        return result.returncode, result.stdout.strip()

    def pick(self, prompt, rows, hint):
        code, index = self.run(prompt, rows, hint,
                               ["-markup-rows", "-format", "i", "-kb-custom-1", "Alt+d"])
        if code not in (0, 10) or not index.isdigit():
            return None
        return Choice(int(index), delete=code == 10)

    def ask(self, prompt, options, hint=""):
        code, text = self.run(prompt, options, hint)
        return text if code == 0 and text else None


# ── the running session (Adapter over hyprctl) ────────────────────────────

class Desktop:
    def query(self, what):
        return json.loads(subprocess.check_output(["hyprctl", what, "-j"]))

    def dispatch(self, expr):
        subprocess.run(["hyprctl", "dispatch", expr], stdout=subprocess.DEVNULL)

    def launch(self, argv):
        subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)

    @staticmethod
    def command_of(pid):
        try:
            raw = Path(f"/proc/{pid}/cmdline").read_bytes()
        except OSError:
            return None
        return [part.decode(errors="replace") for part in raw.split(b"\0") if part]

    def capture(self):
        """The layout entries for the windows open now."""
        return snapshot(self.query("clients"), self.query("monitors"), self.command_of)

    def reopen(self, entry, monitors, wait=WAIT):
        """Launches one window again and puts it back; False if it did not
        show up in time."""
        before = {c["address"] for c in self.query("clients")}
        self.launch(launch_argv(entry["command"]))
        deadline = time.monotonic() + wait
        while time.monotonic() < deadline:
            time.sleep(0.25)
            address = next((c["address"] for c in self.query("clients")
                            if c["address"] not in before
                            and c.get("initialClass") == entry["initialClass"]), None)
            if address:
                for expr in placement(entry, monitors, address):
                    self.dispatch(expr)
                return True
        return False


def notify(body, urgency="normal"):
    subprocess.run(["notify-send", "-a", "Layouts", "-u", urgency, "Layouts", body])


# ── the flows ─────────────────────────────────────────────────────────────

class SessionManager:
    """The flows. It knows none of the concrete pieces: main() picks them
    (rofi, hyprctl, notify-send) and the tests pass fakes."""

    def __init__(self, layouts, menu, desktop, notify):
        self.layouts = layouts
        self.menu = menu
        self.desktop = desktop
        self.notify = notify

    def save(self):
        """Ask for a name (the existing ones listed, to overwrite) and save."""
        names = [n for n in self.layouts.names() if n != LAST]
        name = self.menu.ask("  Save as", names, "Type a new name, or pick one to overwrite it")
        if not name:
            return
        name = name.replace("/", "-").replace(" ", "-")
        existed = self.layouts.exists(name)
        if existed and self.menu.ask(f"  Overwrite '{name}'?", ["Cancel", "Overwrite"]) != "Overwrite":
            return
        entries = self.desktop.capture()
        self.layouts.save(name, entries)
        self.notify(f"'{name}' {'updated' if existed else 'saved'}: {len(entries)} windows")

    def logout(self):
        entries = self.desktop.capture()
        self.layouts.save(LAST, entries)
        self.notify(f"Session saved ({len(entries)} windows). Logging out…", "critical")
        time.sleep(0.5)
        self.desktop.dispatch("hl.dsp.exit()")

    def load(self):
        """Pick a layout and reopen it; Alt+D deletes the picked one and
        shows the list again."""
        while True:
            found = self.layouts.all()
            if not found:
                self.notify(f"No saved layouts yet. Save one with Super+W ({self.layouts.folder})")
                return
            rows = [f"<b>{html.escape(title(name))}</b>   "
                    f"<span alpha='55%'>{html.escape(describe(entries, age))}</span>"
                    for name, entries, age in found]
            choice = self.menu.pick("  Layout", rows, "Enter: open  ·  Alt+D: delete")
            if choice is None:
                return
            name, entries, _ = found[choice.index]
            if choice.delete:
                self.layouts.delete(name)
                self.notify(f"'{title(name)}' deleted")
                continue
            self.restore(name, entries)
            return

    def restore(self, name, entries):
        monitors = self.desktop.query("monitors")
        missing = [e["class"] for e in entries if not self.desktop.reopen(e, monitors)]
        body = f"'{title(name)}': {len(entries) - len(missing)} of {len(entries)} windows back"
        if missing:
            body += f"\nDid not open: {', '.join(missing)}"
        self.notify(body, "critical" if missing else "normal")


def main(argv):
    if len(argv) != 2 or argv[1] not in ("save", "logout", "load"):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 1
    # Composition root: the one place that chooses the concrete pieces.
    manager = SessionManager(Layouts(), RofiMenu(), Desktop(), notify)
    getattr(manager, argv[1])()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
