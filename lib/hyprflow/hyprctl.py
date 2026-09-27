"""Hyprland over hyprctl, in one place (Facade): JSON queries and Lua
dispatches. Scripts ask for what they need instead of building commands."""

import json
import subprocess


def query(*what):
    """hyprctl's JSON for a query: query("clients"), query("monitors", "all")."""
    return json.loads(subprocess.check_output(["hyprctl", *what, "-j"]))


def _run(*args):
    result = subprocess.run(["hyprctl", *args], capture_output=True, text=True)
    return (result.stdout or result.stderr).strip()


def dispatch(expr):
    """Runs a Lua dispatch, e.g. dispatch("hl.dsp.exit()"); hyprctl's answer."""
    return _run("dispatch", expr)


def batch(*exprs):
    """Several dispatches in one hyprctl call, in order; hyprctl's answer."""
    return _run("--batch", " ; ".join(f"dispatch {e}" for e in exprs))


def on_screen(message, milliseconds=2000, colour="rgb(ff9e64)"):
    """Hyprland's own small notice, shown even with notifications silenced."""
    _run("notify", "-1", str(milliseconds), colour, message)
