#!/usr/bin/env python3
"""Hold PS + Options on a controller for a second to toggle game mode.

Hyprland binds keys, mice and touchpads but ignores gamepads, so this runs
alongside it (hyprland.lua starts it) and watches every connected controller,
picking up the ones that connect later. On Xbox style pads the same buttons
are Guide + Menu.

It only reads: the controller is not grabbed, so Steam and games still get
every press. Holding, rather than pressing, keeps it from firing when PS or
Options are used on their own.

ComboHold is the timing, one per controller, with the clock passed in so it
can be tested without waiting. PadListener is the device side: finding
controllers, reading them and running the action.
"""

import fcntl
import os
import select
import subprocess
import sys
import time

import evdev
from evdev import ecodes as ec

COMBO = frozenset({ec.BTN_MODE, ec.BTN_START})  # PS + Options
HOLD = 1.0                                      # seconds both must stay down
RESCAN = 3.0                                    # seconds between looks for new controllers
ACTION = [os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "bin", "game-mode.sh"), "toggle"]


class ComboHold:
    """Fires once each time the whole combo is held for `hold` seconds."""

    def __init__(self, combo=COMBO, hold=HOLD):
        self.combo = combo
        self.hold = hold
        self.down = set()
        self.since = None   # when the whole combo went down
        self.fired = False  # already fired during this hold

    def key(self, code, pressed, now):
        if code not in self.combo:
            return
        if pressed:
            self.down.add(code)
        else:
            self.down.discard(code)
        if self.down == self.combo:
            if self.since is None:
                self.since = now
        else:
            self.since = None
            self.fired = False  # released: the next hold may fire again

    def due(self, now):
        """True once per hold, when it has lasted long enough."""
        if self.since is None or self.fired or now - self.since < self.hold:
            return False
        self.fired = True
        return True

    def wait(self, now):
        """Seconds until due() could turn true, or None if nothing is held."""
        if self.since is None or self.fired:
            return None
        return max(0.0, self.since + self.hold - now)


def is_pad(device):
    return COMBO.issubset(device.capabilities().get(ec.EV_KEY, []))


def run_action(action=ACTION):
    subprocess.Popen(action, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


class PadListener:
    def __init__(self, action=run_action, clock=time.monotonic):
        self.action = action
        self.clock = clock
        self.pads = {}  # fd -> (InputDevice, ComboHold)

    def rescan(self):
        """Opens the controllers that connected since the last look."""
        known = {device.path for device, _ in self.pads.values()}
        for path in evdev.list_devices():
            if path in known:
                continue
            try:
                device = evdev.InputDevice(path)
            except OSError:
                continue
            if is_pad(device):
                self.pads[device.fd] = (device, ComboHold())
            else:
                device.close()

    def read(self, fd):
        """Feeds a controller's pending events to its ComboHold."""
        device, hold = self.pads[fd]
        try:
            for event in device.read():
                if event.type == ec.EV_KEY:
                    hold.key(event.code, event.value != 0, self.clock())
        except BlockingIOError:
            pass
        except OSError:  # the controller went away (switched off, out of range)
            device.close()
            del self.pads[fd]

    def fire_due(self):
        now = self.clock()
        for _, hold in self.pads.values():
            if hold.due(now):
                self.action()

    def timeout(self):
        """Sleep until the next rescan, or until a hold completes."""
        now = self.clock()
        waits = [w for _, hold in self.pads.values() if (w := hold.wait(now)) is not None]
        return min([RESCAN, *waits])

    def run(self):
        last_scan = -RESCAN
        while True:
            if self.clock() - last_scan >= RESCAN:
                last_scan = self.clock()
                self.rescan()
            timeout = self.timeout()
            if self.pads:
                ready = select.select(list(self.pads), [], [], timeout)[0]
            else:
                time.sleep(timeout)
                ready = []
            for fd in ready:
                self.read(fd)
            self.fire_due()


def single_instance():
    """Exits if another copy already runs (a Hyprland restart, say)."""
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    lock = open(os.path.join(runtime, "pad-listener.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        sys.exit(0)
    return lock  # kept open for the life of the process


if __name__ == "__main__":
    _lock = single_instance()
    PadListener().run()
