"""Hyprland over hyprctl, in one place (Facade): JSON queries and Lua
dispatches. Scripts ask for what they need instead of building commands.

Every failure (no hyprctl, Hyprland not answering, an error, output that is
not JSON) comes out as one exception, HyprctlError. It is an OSError, so the
`except OSError` a caller already has for a missing command covers it too."""

import json
import os
import socket
import subprocess

from . import paths

TIMEOUT = 5  # seconds; Hyprland answers in milliseconds, or is stuck


class HyprctlError(OSError):
    """hyprctl could not give an answer."""


def _call(args):
    try:
        return subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        raise HyprctlError(f"hyprctl {' '.join(args)}: no answer in {TIMEOUT} s") from None
    except OSError as err:
        raise HyprctlError(f"hyprctl: {err.strerror or err}") from None


def query(*what):
    """hyprctl's JSON for a query: query("clients"), query("monitors", "all")."""
    result = _call([*what, "-j"])
    if result.returncode != 0:
        raise HyprctlError(f"hyprctl {' '.join(what)}: {(result.stderr or result.stdout).strip()}")
    try:
        return json.loads(result.stdout)
    except ValueError:
        raise HyprctlError(f"hyprctl {' '.join(what)}: not JSON: {result.stdout[:80]!r}") from None


def _run(*args):
    result = _call(args)
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
