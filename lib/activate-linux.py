#!/usr/bin/env python3
"""The "Activate Linux" joke watermark, bottom right of the first monitor.

A GTK 4 layer-shell surface on the overlay, like master-pick: no window,
no focus, and an empty input region, so clicks go straight through to what
is underneath. Hyprland starts it once at login; a second copy exits.

It follows workspace 1 when monitors come and go, and hides in game mode.
"""

import ctypes
import fcntl
import os
import sys
import threading

# Must load before gi imports GTK, or the surface comes up as a normal window.
ctypes.CDLL("libgtk4-layer-shell.so", mode=ctypes.RTLD_GLOBAL)

import cairo  # noqa: E402
import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402
from gi.repository import Gtk4LayerShell as LayerShell  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from hyprflow import hyprctl, paths  # noqa: E402

TITLE = "Activate Linux"
SUBTITLE = "Go to Settings to activate Linux"
MARGIN_RIGHT, MARGIN_BOTTOM = 8, 32  # where eww put it
GAME_MODE = paths.HYPRFLOW_STATE / "game-mode"
# Events after which workspace 1 may sit on another monitor.
MOVES = ("monitoradded", "monitorremoved", "moveworkspace")
SETTLE_MS = 500  # a hotplug comes as a burst; place once it is over
CSS = """
window { background-color: transparent; }
.title    { color: rgba(250, 250, 250, 0.5); font-size: 1.25em; }
.subtitle { color: rgba(250, 250, 250, 0.5); }
"""


def single_instance():
    """Exits if another copy already runs (a Hyprland reload, say)."""
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    lock = open(os.path.join(runtime, "activate-linux.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)
    return lock  # kept open for the life of the process


def label(text, css_class):
    widget = Gtk.Label(label=text, xalign=0)
    widget.add_css_class(css_class)
    return widget


def primary_port():
    """The connector showing workspace 1: monitors.sh gives it to the primary."""
    try:
        return next((w["monitor"] for w in hyprctl.query("workspaces") if w["id"] == 1), None)
    except (OSError, ValueError):
        return None


def target(monitors, port, gaming):
    """Where the watermark goes: nowhere in game mode, else the monitor
    showing workspace 1, else the first one."""
    if gaming or not monitors:
        return None
    return next((m for m in monitors if m.get_connector() == port), monitors[0])


class Watermark:
    def __init__(self, app):
        self.window = Gtk.ApplicationWindow(application=app)
        self.monitor = None
        self.pending = 0
        self.monitors = Gdk.Display.get_default().get_monitors()

    def build(self):
        window = self.window
        LayerShell.init_for_window(window)
        LayerShell.set_namespace(window, "activate-linux")
        LayerShell.set_layer(window, LayerShell.Layer.OVERLAY)
        LayerShell.set_keyboard_mode(window, LayerShell.KeyboardMode.NONE)
        LayerShell.set_anchor(window, LayerShell.Edge.RIGHT, True)
        LayerShell.set_anchor(window, LayerShell.Edge.BOTTOM, True)
        LayerShell.set_margin(window, LayerShell.Edge.RIGHT, MARGIN_RIGHT)
        LayerShell.set_margin(window, LayerShell.Edge.BOTTOM, MARGIN_BOTTOM)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        box.append(label(TITLE, "title"))
        box.append(label(SUBTITLE, "subtitle"))
        window.set_child(box)

        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        # Click-through: an empty input region, set once the surface exists.
        window.connect("realize", lambda w: w.get_surface().set_input_region(cairo.Region()))

        self.monitors.connect("items-changed", lambda *_: self.later())
        self.game_mode = Gio.File.new_for_path(str(GAME_MODE)).monitor_file(Gio.FileMonitorFlags.NONE)
        self.game_mode.connect("changed", lambda *_: self.later())
        threading.Thread(target=self.listen, daemon=True).start()
        self.place()

    def listen(self):
        try:
            for line in hyprctl.events():
                if line.startswith(MOVES):
                    GLib.idle_add(self.later)
        except OSError:
            pass  # no event socket: it stays where it started

    def later(self):
        if self.pending:
            GLib.source_remove(self.pending)
        self.pending = GLib.timeout_add(SETTLE_MS, self.place)
        return False

    def place(self):
        self.pending = 0
        items = [self.monitors.get_item(i) for i in range(self.monitors.get_n_items())]
        monitor = target(items, primary_port(), GAME_MODE.exists())
        if monitor is None:
            self.window.set_visible(False)
        elif monitor != self.monitor or not self.window.get_visible():
            # A layer surface picks its output when it maps: unmap, then map again.
            self.window.set_visible(False)
            LayerShell.set_monitor(self.window, monitor)
            self.window.present()
        self.monitor = monitor
        return False


def main():
    with single_instance():
        app = Gtk.Application(application_id="dev.hyprflow.activatelinux")
        app.connect("activate", lambda app: Watermark(app).build())
        return app.run([])


if __name__ == "__main__":
    sys.exit(main())
