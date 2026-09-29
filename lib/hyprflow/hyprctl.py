"""Hyprland over hyprctl, in one place (Facade): JSON queries and Lua
dispatches. Scripts ask for what they need instead of building commands."""

import json
import os
import socket
import subprocess

from . import paths


def query(*what):
    """hyprctl's JSON for a query: query("clients"), query("monitors", "all")."""
    return json.loads(subprocess.check_output(["hyprctl", *what, "-j"]))


def _run(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True)
    return (result.stdout or result.stderr).strip()


def reload():
    """Reloads Hyprland's config; hyprctl's answer."""
    return _run("reload")


def dispatch(expr):
    """Runs a Lua dispatch, e.g. dispatch("hl.dsp.exit()"); hyprctl's answer."""
    return _run("dispatch", expr)


def batch(*exprs):
    """Several dispatches in one hyprctl call, in order; hyprctl's answer."""
    return _run("--batch", " ; ".join(f"dispatch {e}" for e in exprs))


def on_screen(message, milliseconds=2000, colour="rgb(ff9e64)"):
    """Hyprland's own small notice, shown even with notifications silenced."""
    _run("notify", "-1", str(milliseconds), colour, message)


def events():
    """Hyprland's event stream, one "name>>data" line at a time, until the
    socket closes. Blocks, so run it in a thread; OSError if there is none."""
    his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not his:
        raise OSError("not running under Hyprland")
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.connect(str(paths.RUNTIME / "hypr" / his / ".socket2.sock"))
        with sock.makefile("r", encoding="utf-8", errors="replace") as stream:
            for line in stream:
                yield line.rstrip("\n")
