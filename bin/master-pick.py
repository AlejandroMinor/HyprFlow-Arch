#!/usr/bin/env python3
"""Numbers every window in the active workspace and swaps the chosen one to
master. Bound to Super+Shift+Return.

No submap needed: the overlay grabs the keyboard exclusively. 0-9 picks a
window (0 is always the current master), Escape cancels, 15s timeout as a net.

  --notify   report via hyprctl when there are fewer than 2 windows;
             silent no-op otherwise.
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
  background-color: alpha(#0d0d14, 0.92);
  color: #ff9e64;
  font-family: monospace;
  font-size: 42px;
  font-weight: 700;
  border: 1px solid #33344a;
  border-radius: 10px;
  padding: 6px 24px;
}
"""

# Roughly half the label size, to centre it on the window.
LABEL_HALF_W = 40
LABEL_HALF_H = 38


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


class MasterPick(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.alex.masterpick")
        self.clients = []
        self.choice = None  # dispatched after the overlay closes, not before
        self.win = None

    def do_activate(self):
        mon = next(m for m in hyprctl_json("monitors") if m["focused"])
        ws_id = mon["activeWorkspace"]["id"]

        # Sorted by x, so index 0 is the master.
        self.clients = sorted(
            (
                c
                for c in hyprctl_json("clients")
                if c["workspace"]["id"] == ws_id and c["mapped"]
            ),
            key=lambda c: (c["at"][0], c["at"][1]),
        )[:10]

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

        win = Gtk.Window(application=self)
        self.win = win
        LayerShell.init_for_window(win)
        LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
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
        for i, c in enumerate(self.clients, start=0):
            label = Gtk.Label(label=str(i))
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

        digit = keyval_to_digit(keyval)
        if digit is not None and digit < len(self.clients):
            log(f"picked {digit}")
            self.choice = digit
            self.close_overlay()
        return True  # every other key is swallowed; the grab is exclusive


if __name__ == "__main__":
    app = MasterPick()
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
