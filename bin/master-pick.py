#!/usr/bin/env python3
"""Numbers every window in the active workspace and swaps the chosen one to
master. Bound to Super+Shift+Return.

Requires Hyprland 0.55+ on the Lua config provider: the dispatches at the
bottom are hl.dsp.* expressions, deliberately Lua-only. On a .conf setup the
overlay still works and the pick silently does nothing.

No submap needed: the overlay grabs the keyboard exclusively. A digit or
letter (depending on --labels) picks a window, Escape cancels, 15s timeout
as a net.

  --notify         report via hyprctl when there are fewer than 2 windows;
                    silent no-op otherwise.
  --labels=MODE     "letters" (default, up to 26, fixed order f/j/d/k/s/l/a/h/g
                    then the top row then the bottom one, by position in the
                    sorted client list — master is always "f") or "numbers"
                    (capped at 10 windows since there are only ten digits,
                    master is "1").
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

# Pill colours. The background alpha is deliberately low: hyprglass composites
# its glass underneath this surface (see hg.layer("master-pick") in
# hyprland.lua), and a solid fill would bury it.
LABEL_BG = "#3a3a3a"
LABEL_BG_ALPHA = 0.15
LABEL_FG = "#f5f5f5"
LABEL_BORDER = "#4a4a4a"

# Safety net: a stray invocation shouldn't sit there holding the keyboard grab.
PICK_TIMEOUT_SECONDS = 15

CSS = f"""
window {{ background-color: transparent; }}
.mp-label {{
  background-color: alpha({LABEL_BG}, {LABEL_BG_ALPHA});
  color: {LABEL_FG};
  font-family: monospace;
  font-weight: 700;
  border: 1px solid {LABEL_BORDER};
}}
"""

# Pill size at scale 1.0, scaled per window below. Not much smaller than this
# or hyprglass's edge band has no room and the glass reads as a flat box.
BASE_FONT_SIZE = 64
BASE_PAD_V = 10
BASE_PAD_H = 32
BASE_RADIUS = 14

# The window dimension (its smaller side) that maps to scale 1.0.
SCALE_REFERENCE_PX = 700
SCALE_MIN = 0.5
SCALE_MAX = 1.3


def label_scale(client):
    """Window's smaller side vs. the reference size, clamped to a sane range
    -- so it degrades gracefully instead of vanishing on a thin tiled column
    or ballooning on a single fullscreen-ish window."""
    min_dim = min(client["size"][0], client["size"][1])
    return max(SCALE_MIN, min(SCALE_MAX, min_dim / SCALE_REFERENCE_PX))


def label_css(scale):
    """Per-widget override for the size-dependent properties. Loaded at
    STYLE_PROVIDER_PRIORITY_USER, above the shared .mp-label class (loaded at
    _APPLICATION), so it wins on the properties it sets while still
    inheriting color/background/border from the shared class."""
    return f"""
    label {{
        font-size: {round(BASE_FONT_SIZE * scale)}px;
        padding: {round(BASE_PAD_V * scale)}px {round(BASE_PAD_H * scale)}px;
        border-radius: {round(BASE_RADIUS * scale)}px;
    }}
    """

# Index fingers first, then outward, row by row. Slot N always gets the same
# letter so it can be muscle-memorized: only ever append here, never reorder.
# No punctuation -- those are level-3 keys on the es/us layout.
LETTER_LABELS = [
    "f", "j", "d", "k", "s", "l", "a", "h", "g",       # home row
    "r", "u", "e", "i", "w", "o", "q", "p", "t", "y",  # top row
    "v", "n", "c", "m", "x", "z", "b",                 # bottom row, last resort
]

# Numbers caps at 10 because there are only ten digits; letters goes further.
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


DEFAULT_LABELS_MODE = "letters"


def parse_labels_mode(argv):
    mode = DEFAULT_LABELS_MODE
    for arg in argv:
        if arg.startswith("--labels="):
            mode = arg.split("=", 1)[1]
    if mode not in CAP_BY_MODE:
        log(f"unknown --labels value {mode!r}, falling back to {DEFAULT_LABELS_MODE}")
        mode = DEFAULT_LABELS_MODE
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
            # GtkApplication is single-instance, so a second press re-enters
            # do_activate here rather than starting a process. Toggle it shut.
            log("already open, closing (toggle)")
            self.close_overlay()
            return

        mon = next(m for m in hyprctl_json("monitors") if m["focused"])
        ws_id = mon["activeWorkspace"]["id"]

        # Sorted by x, so index 0 is the master. No floating windows: they sit
        # outside the tiled stack, where swapwithmaster no-ops, and one could
        # take the master label by x-position alone.
        all_clients = sorted(
            (
                c
                for c in hyprctl_json("clients")
                if c["workspace"]["id"] == ws_id
                and c["mapped"]
                and not c["floating"]
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
        LayerShell.set_namespace(win, "master-pick")  # matched by windowrules.lua and hyprglass in hyprland.lua
        LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (
            LayerShell.Edge.TOP,
            LayerShell.Edge.BOTTOM,
            LayerShell.Edge.LEFT,
            LayerShell.Edge.RIGHT,
        ):
            LayerShell.set_anchor(win, edge, True)
        # -1 spans the whole output, ignoring the bar's exclusive zone.
        # Otherwise the surface starts below it and local 0,0 isn't the
        # monitor's, putting every label the bar's height too low.
        LayerShell.set_exclusive_zone(win, -1)

        css = Gtk.CssProvider()
        css.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        fixed = Gtk.Fixed()
        for i, c in enumerate(self.clients):
            label = Gtk.Label(label=self.labels[i])
            label.add_css_class("mp-label")

            scale = label_scale(c)
            size_css = Gtk.CssProvider()
            size_css.load_from_string(label_css(scale))
            label.get_style_context().add_provider(
                size_css, Gtk.STYLE_PROVIDER_PRIORITY_USER
            )

            # Real rendered size, so nothing has to track the CSS by hand.
            # Works before the label is mapped, unlike get_width/get_height.
            _, w, _, _ = label.measure(Gtk.Orientation.HORIZONTAL, -1)
            _, h, _, _ = label.measure(Gtk.Orientation.VERTICAL, -1)

            # hyprctl coordinates are global; subtract the monitor offset.
            cx = c["at"][0] - mon["x"] + c["size"][0] // 2
            cy = c["at"][1] - mon["y"] + c["size"][1] // 2
            fixed.put(label, max(cx - w // 2, 0), max(cy - h // 2, 0))
        win.set_child(fixed)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self.on_key)
        win.add_controller(keys)

        GLib.timeout_add_seconds(PICK_TIMEOUT_SECONDS, self.close_overlay)
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
