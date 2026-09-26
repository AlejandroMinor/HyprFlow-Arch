"""Base for Waybar custom modules that update on events.

Waybar runs these as continuous modules (no "interval"): the script stays up
and prints a JSON line whenever the state changes. What every such module
needs is here, once:

  - print the state at start, then again whenever an event arrives
  - skip a line identical to the last one (most events change nothing shown)
  - start the event source again if it ends (PipeWire restarting, say)
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

This lives outside bin/ so install.sh does not link it into ~/.local/bin;
the scripts load it from the repo (see bin/*.py headers).
"""

import ctypes
import json
import os
import signal
import subprocess
import sys
import time

PR_SET_PDEATHSIG = 1
libc = ctypes.CDLL("libc.so.6", use_errno=True)


def die_with_parent():
    """Asks the kernel for SIGTERM when the parent (Waybar) exits."""
    libc.prctl(PR_SET_PDEATHSIG, signal.SIGTERM)


def lines(cmd):
    """Yields the output lines of a long running command, which dies with
    this process too (an orphaned pactl would otherwise stay up)."""
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                          text=True, preexec_fn=die_with_parent) as proc:
        yield from proc.stdout


class WaybarModule:
    """The skeleton every event driven module shares; see the module docs."""

    restart_delay = 1.0  # seconds before starting an ended event source again

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
        self.emit()
        while True:
            try:
                for _ in self.events():
                    self.emit()
            except OSError:
                pass
            time.sleep(self.restart_delay)
            self.emit()  # the state may have changed while the source was down
