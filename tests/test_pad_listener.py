"""Tests for lib/pad-listener.py. The clock is passed in and the controllers
are fakes, so nothing waits a real second or needs a pad plugged in."""

import os
from types import SimpleNamespace

import pytest
from evdev import ecodes as ec

PS, OPTIONS, CROSS = ec.BTN_MODE, ec.BTN_START, ec.BTN_SOUTH


# ComboHold: the timing

def test_fires_once_after_holding_the_combo(pad):
    hold = pad.ComboHold()
    hold.key(PS, True, 0.0)
    hold.key(OPTIONS, True, 0.2)
    assert not hold.due(1.1)    # the whole combo is down since 0.2 only
    assert hold.due(1.2)
    assert not hold.due(5.0)    # still held: no second shot


def test_a_short_press_does_not_fire(pad):
    hold = pad.ComboHold()
    hold.key(PS, True, 0.0)
    hold.key(OPTIONS, True, 0.0)
    hold.key(OPTIONS, False, 0.5)
    assert not hold.due(2.0)


def test_one_button_alone_never_fires(pad):
    hold = pad.ComboHold()
    hold.key(PS, True, 0.0)
    assert not hold.due(10.0)


def test_other_buttons_do_not_break_the_hold(pad):
    hold = pad.ComboHold()
    hold.key(PS, True, 0.0)
    hold.key(OPTIONS, True, 0.0)
    hold.key(CROSS, True, 0.5)
    assert hold.due(1.0)


def test_releasing_rearms_it(pad):
    hold = pad.ComboHold()
    for start in (0.0, 5.0):
        hold.key(PS, True, start)
        hold.key(OPTIONS, True, start)
        assert hold.due(start + 1.0)
        hold.key(PS, False, start + 2.0)
        hold.key(OPTIONS, False, start + 2.0)


def test_wait_is_the_time_left_on_the_hold(pad):
    hold = pad.ComboHold()
    assert hold.wait(0.0) is None
    hold.key(PS, True, 0.0)
    hold.key(OPTIONS, True, 0.0)
    assert hold.wait(0.25) == pytest.approx(0.75)
    hold.due(1.0)
    assert hold.wait(1.5) is None   # fired: nothing left to wait for


# PadListener: the device side, on fake controllers

class FakeDevice:
    def __init__(self, path, keys, fd):
        self.path, self.fd, self.keys = path, fd, keys
        self.events, self.gone, self.closed = [], False, False

    def capabilities(self):
        return {ec.EV_KEY: self.keys}

    def read(self):
        if self.gone:
            raise OSError("No such device")
        events, self.events = self.events, []
        return events

    def close(self):
        self.closed = True

    def press(self, code, down=True):
        self.events.append(SimpleNamespace(type=ec.EV_KEY, code=code, value=int(down)))


@pytest.fixture
def devices(pad, monkeypatch):
    found = {}
    monkeypatch.setattr(pad.evdev, "list_devices", lambda: list(found))
    monkeypatch.setattr(pad.evdev, "InputDevice", lambda path: found[path])
    return found


@pytest.fixture
def listener(pad):
    clock = SimpleNamespace(now=0.0)
    fired = []
    listener = pad.PadListener(action=lambda: fired.append(clock.now), clock=lambda: clock.now)
    return listener, clock, fired


def test_rescan_keeps_only_controllers(pad, devices, listener):
    ds4 = devices["/dev/input/event20"] = FakeDevice("/dev/input/event20", [PS, OPTIONS, CROSS], 20)
    kbd = devices["/dev/input/event3"] = FakeDevice("/dev/input/event3", [ec.KEY_A], 3)
    lst, _, _ = listener
    lst.rescan()
    assert list(lst.pads) == [20]
    assert kbd.closed and not ds4.closed


def test_rescan_picks_up_a_controller_connected_later(pad, devices, listener):
    lst, _, _ = listener
    lst.rescan()
    assert lst.pads == {}
    devices["/dev/input/event21"] = FakeDevice("/dev/input/event21", [PS, OPTIONS], 21)
    lst.rescan()
    assert list(lst.pads) == [21]


def test_holding_on_a_controller_runs_the_action_once(pad, devices, listener):
    ds4 = devices["/dev/input/event20"] = FakeDevice("/dev/input/event20", [PS, OPTIONS], 20)
    lst, clock, fired = listener
    lst.rescan()
    ds4.press(PS)
    ds4.press(OPTIONS)
    lst.read(20)
    clock.now = 0.5
    lst.fire_due()
    assert fired == []
    clock.now = 1.0
    lst.fire_due()
    lst.fire_due()
    assert fired == [1.0]


def test_each_controller_holds_on_its_own(pad, devices, listener):
    a = devices["/dev/input/event20"] = FakeDevice("/dev/input/event20", [PS, OPTIONS], 20)
    b = devices["/dev/input/event21"] = FakeDevice("/dev/input/event21", [PS, OPTIONS], 21)
    lst, clock, fired = listener
    lst.rescan()
    a.press(PS)          # PS on one pad, Options on the other: not a combo
    b.press(OPTIONS)
    lst.read(20)
    lst.read(21)
    clock.now = 2.0
    lst.fire_due()
    assert fired == []


def test_a_controller_that_goes_away_is_dropped(pad, devices, listener):
    ds4 = devices["/dev/input/event20"] = FakeDevice("/dev/input/event20", [PS, OPTIONS], 20)
    lst, _, _ = listener
    lst.rescan()
    ds4.gone = True
    lst.read(20)
    assert lst.pads == {} and ds4.closed


def test_timeout_wakes_up_when_a_hold_completes(pad, devices, listener):
    ds4 = devices["/dev/input/event20"] = FakeDevice("/dev/input/event20", [PS, OPTIONS], 20)
    lst, clock, _ = listener
    lst.rescan()
    assert lst.timeout() == pad.RESCAN
    ds4.press(PS)
    ds4.press(OPTIONS)
    lst.read(20)
    clock.now = 0.4
    assert lst.timeout() == pytest.approx(0.6)


def test_the_action_is_game_mode_toggle(pad):
    script, arg = pad.ACTION
    assert script.endswith("bin/game-mode.sh") and arg == "toggle"
    assert os.path.exists(script)
