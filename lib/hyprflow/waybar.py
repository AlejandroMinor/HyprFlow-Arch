"""Base for Waybar custom modules that update on events.

Waybar runs these as continuous modules (no "interval"): the script stays up
and prints a JSON line whenever the state changes. What every such module
needs is here, once:

  - print the state at start, then again whenever an event arrives
  - skip a line identical to the last one (most events change nothing shown)
  - start the event source again if it ends (PipeWire restarting, say)
  - survive a failing state() or event source: log it, wait, try again, backing
    off up to a minute, instead of dying and freezing that part of the bar.
    Waybar sends its modules' stderr to /dev/null, so errors also go to the
    journal: `journalctl -t hyprflow`
  - die with the Waybar that started it, and take the event source along:
    Waybar does not stop its continuous modules when it exits, so without
    this every Waybar restart left a copy running

A module fills in two steps (Template Method):

    class VpnStatus(WaybarModule):
        def state(self):          # what to show now, as Waybar's JSON dict
            ...
        def events(self):         # yields whenever the state may have changed
            yield from lines(["ip", "-o", "monitor", "link"])

    VpnStatus().run()

Part of the hyprflow package (lib/hyprflow/), off PATH like the rest of lib/:
modules import it as `from hyprflow.waybar import WaybarModule`.
"""

import ctypes
import json
import os
import signal
import subprocess
import sys
import syslog
import time

PR_SET_PDEATHSIG = 1
libc = ctypes.CDLL("libc.so.6", use_errno=True)


def die_with_parent():
    """Asks the kernel for SIGTERM when the parent (Waybar) exits."""
    libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM)


def lines(cmd):
    """Yields the output lines of a long running command, which dies with
    this process too (an orphaned pactl would otherwise stay up).

    preexec_fn is not safe in a process with threads: a module using this
    must not start any (none does today)."""
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          text=True, preexec_fn=die_with_parent) as proc:
        try:
            yield from proc.stdout
        finally:
            # Left early (the module's state() failed): stop the command now.
            # Otherwise closing waits for it to exit, and a quiet one (pactl
            # subscribe) holds the module until its next event.
            proc.terminate()


def log_error(message):
    """To stderr, for a module run by hand, and to the journal, since under
    Waybar stderr goes nowhere."""
    print(message, file=sys.stderr, flush=True)
    syslog.openlog("hyprflow")
    syslog.syslog(syslog.LOG_WARNING, message)


class WaybarModule:
    """The skeleton every event driven module shares; see the module docs."""

    restart_delay = 1.0  # seconds before starting an ended event source again
    max_delay = 60.0     # the longest wait between retries after errors

    def state(self):
        """The Waybar JSON dict for right now."""
        raise NotImplementedError

    def events(self):
        """Yields whenever the state may have changed; may end."""
        raise NotImplementedError

    def __init__(self):
        self._last = None

    def emit(self):
        """Prints the state, unless it is what was printed last."""
        out = json.dumps(self.state())
        if out != self._last:
            self._last = out
            print(out, flush=True)

    def run(self):
        die_with_parent()
        if os.getppid() == 1:  # Waybar already gone before the line above
            sys.exit(0)
        delay = self.restart_delay
        while True:
            try:
                self.emit()
                for _ in self.events():
                    self.emit()
                delay = self.restart_delay  # ended cleanly: back to a short wait
            except Exception as err:  # a dead module freezes its part of the bar
                log_error(f"{type(self).__name__}: {err!r}")
                time.sleep(delay)
                delay = min(delay * 2, self.max_delay)
                continue
            time.sleep(delay)
