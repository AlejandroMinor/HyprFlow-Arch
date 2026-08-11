#!/usr/bin/env python3
"""Numbers every window in the active workspace and swaps the chosen one to
master. Bound to Super+Shift+Return.

No submap needed: the overlay grabs the keyboard exclusively. A digit or
letter (depending on --labels) picks a window, Escape cancels, 15s timeout
as a net.

  --notify         report via hyprctl when there are fewer than 2 windows;
                    silent no-op otherwise.
  --labels=MODE     "numbers" (default, up to 10 windows, master is "1") or
                    "letters" (up to 9 windows, fixed home-row order
                    f/j/d/k/s/l/a/h/g by position in the sorted client
                    list — master is always "f").
"""
import ctypes
import json
import subprocess
import sys
import time

# Must load before gi imports GTK, or the window comes up as a normal toplevel
# and the tiler swallows it.
ctypes.CDLL("libgtk4-layer-shell.so", mode=ctypes.RTLD_GLOBAL)

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402
from gi.repository import Gtk4LayerShell as LayerShell  # noqa: E402

CSS = """
window { background-color: transparent; }
.mp-label {
  background-color: alpha(#111111, 0.55);
  color: #f5f5f5;
  font-family: monospace;
  font-size: 42px;
  font-weight: 700;
  border: 1px solid #4a4a4a;
  border-radius: 10px;
  padding: 6px 24px;
}
"""

# Roughly half the label size, to centre it on the window.
LABEL_HALF_W = 40
LABEL_HALF_H = 38

# Fixed home-row order, starting at the resting index-finger keys (F/J) and
# alternating outward. Index i always maps to the same letter regardless of
# window position, so the label for a given slot (master, 2nd, ...) stays
# constant across invocations and can be muscle-memorized.
LETTER_LABELS = ["f", "j", "d", "k", "s", "l", "a", "h", "g"]

CAP_BY_MODE = {"numbers": 10, "letters": len(LETTER_LABELS)}


def log(msg):
    print(f"[master-pick] {msg}", file=sys.stderr)


def hyprctl_json(*args):
    out = subprocess.run(
        ["hyprctl", *args, "-j"], capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out)


def keyval_to_digit(keyval):
    """Top row and numpad -> 0-9, or None."""
    if Gdk.KEY_0 <= keyval <= Gdk.KEY_9:
        return keyval - Gdk.KEY_0
    if Gdk.KEY_KP_0 <= keyval <= Gdk.KEY_KP_9:
        return keyval - Gdk.KEY_KP_0
    return None


def keyval_to_letter(keyval):
    codepoint = Gdk.keyval_to_unicode(keyval)
    if not codepoint:
        return None
    char = chr(codepoint).lower()
    return char if char.isalpha() else None


def parse_labels_mode(argv):
    mode = "numbers"
    for arg in argv:
        if arg.startswith("--labels="):
            mode = arg.split("=", 1)[1]
    if mode not in CAP_BY_MODE:
        log(f"unknown --labels value {mode!r}, falling back to numbers")
        mode = "numbers"
    return mode


def digit_label(index):
    """0-based client index -> digit string; master (0) is '1', wraps 9 -> '0'."""
    return str((index + 1) % 10)


class MasterPick(Gtk.Application):
    def __init__(self, labels_mode):
        super().__init__(application_id="dev.alex.masterpick")
        self.labels_mode = labels_mode
        self.clients = []
        self.labels = []            # client index -> display label (str)
        self.pressed_to_index = {}  # pressed key repr -> client index
        self.choice = None  # dispatched after the overlay closes, not before
        self.win = None

    def do_activate(self):
        if self.win is not None:
            # Single-instance GtkApplication: a second Super+Shift+Return
            # while the overlay is already open re-fires do_activate in
            # this same process. Ignore it instead of stacking a window.
            log("already open, ignoring re-activation")
            return

        mon = next(m for m in hyprctl_json("monitors") if m["focused"])
        ws_id = mon["activeWorkspace"]["id"]

        # Sorted by x, so index 0 is the master.
        all_clients = sorted(
            (
                c
                for c in hyprctl_json("clients")
                if c["workspace"]["id"] == ws_id and c["mapped"]
            ),
            key=lambda c: (c["at"][0], c["at"][1]),
        )

        cap = CAP_BY_MODE[self.labels_mode]
        if len(all_clients) > cap:
            log(f"{len(all_clients)} windows found, only showing first {cap}")
        self.clients = all_clients[:cap]

        log(f"{len(self.clients)} window(s) in workspace {ws_id}")

        if len(self.clients) < 2:
            if "--notify" in sys.argv:
                msg = (
                    "master-pick: no windows in this workspace"
                    if not self.clients
                    else "master-pick: only one window — it's already the master"
                )
                subprocess.run(
                    ["hyprctl", "notify", "-1", "2000", "rgb(ff9e64)", msg],
                    capture_output=True,
                )
            self.quit()
            return

        if self.labels_mode == "numbers":
            self.labels = [digit_label(i) for i in range(len(self.clients))]
            self.pressed_to_index = {
                digit_label(i): i for i in range(len(self.clients))
            }
        else:
            self.labels = LETTER_LABELS[: len(self.clients)]
            self.pressed_to_index = {
                letter: i for i, letter in enumerate(self.labels)
            }

        win = Gtk.Window(application=self)
        self.win = win
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
        LayerShell.set_namespace(win, "master-pick")  # matched by the layer_rule blur in windowrules.lua
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (
            LayerShell.Edge.TOP,
            LayerShell.Edge.BOTTOM,
            LayerShell.Edge.LEFT,
            LayerShell.Edge.RIGHT,
        ):
            LayerShell.set_anchor(win, edge, True)

        css = Gtk.CssProvider()
        css.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        fixed = Gtk.Fixed()
        for i, c in enumerate(self.clients):
            label = Gtk.Label(label=self.labels[i])
            label.add_css_class("mp-label")
            # hyprctl coordinates are global; subtract the monitor offset.
            x = c["at"][0] - mon["x"] + c["size"][0] // 2 - LABEL_HALF_W
            y = c["at"][1] - mon["y"] + c["size"][1] // 2 - LABEL_HALF_H
            fixed.put(label, max(x, 0), max(y, 0))
        win.set_child(fixed)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self.on_key)
        win.add_controller(keys)

        GLib.timeout_add_seconds(15, self.close_overlay)  # safety net
        win.present()

    def close_overlay(self):
        # Destroy the surface before leaving the loop, so the compositor
        # processes it and releases the exclusive keyboard grab.
        if self.win is not None:
            self.win.destroy()
            self.win = None
        GLib.idle_add(self.quit)
        return False  # do not repeat the timeout

    def on_key(self, _ctrl, keyval, _keycode, _state):
        if keyval == Gdk.KEY_Escape:
            log("cancelled")
            self.close_overlay()
            return True

        if self.labels_mode == "numbers":
            digit = keyval_to_digit(keyval)
            pressed = None if digit is None else str(digit)
        else:
            pressed = keyval_to_letter(keyval)

        idx = self.pressed_to_index.get(pressed)
        if idx is not None:
            log(f"picked {pressed}")
            self.choice = idx
            self.close_overlay()
        return True  # every other key is swallowed; the grab is exclusive


if __name__ == "__main__":
    labels_mode = parse_labels_mode(sys.argv[1:])
    app = MasterPick(labels_mode)
    app.run(None)

    # The GTK loop is over and the surface is gone, so the keyboard is back with
    # Hyprland and the dispatch will actually land.
    if app.choice is not None:
        time.sleep(0.05)  # let the compositor process the destroy
        addr = app.clients[app.choice]["address"]
        # This config uses hyprlang-lua, where dispatch takes hl.dsp.*
        # expressions; the legacy "focuswindow address:..." form is gone.
        focus = f"hl.dsp.focus({{window='address:{addr}'}})"
        if app.choice == 0:
            # 0 is already the master, so focus without swapping.
            log(f"focus master {addr}")
            r = subprocess.run(
                ["hyprctl", "dispatch", focus],
                capture_output=True,
                text=True,
            )
        else:
            log(f"swap {addr} → master")
            r = subprocess.run(
                [
                    "hyprctl",
                    "--batch",
                    f"dispatch {focus} ; "
                    "dispatch hl.dsp.layout('swapwithmaster master')",
                ],
                capture_output=True,
                text=True,
            )
        log(f"hyprctl: {r.stdout.strip() or r.stderr.strip()}")
