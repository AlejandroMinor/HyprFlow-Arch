"""Tests for lib/headset-watch.py. headsetcontrol and rgb-sync.sh are never
run: the reader and the action are passed in, or subprocess is faked."""

import json

import pytest


def test_turning_on_recolours_once(headset_watch):
    states = iter([False, False, True, True, False, True])
    calls = []
    watch = headset_watch.PowerWatch(is_on=lambda: next(states), powered_on=lambda: calls.append(1))
    for _ in range(6):
        watch.check()
    assert len(calls) == 2   # off -> on, twice


def test_on_at_the_first_look_does_nothing(headset_watch):
    calls = []
    watch = headset_watch.PowerWatch(is_on=lambda: True, powered_on=lambda: calls.append(1))
    watch.check()
    watch.check()
    assert calls == []


def fake_headsetcontrol(monkeypatch, headset_watch, output):
    monkeypatch.setattr(headset_watch.subprocess, "run",
                        lambda *a, **k: type("R", (), {"stdout": output})())


def test_a_battery_level_means_on(headset_watch, monkeypatch):
    fake_headsetcontrol(monkeypatch, headset_watch,
                        json.dumps({"devices": [{"product": "G733", "battery": {"level": 60}}]}))
    assert headset_watch.headset_on()


@pytest.mark.parametrize("output", [
    json.dumps({"devices": [{"product": "G733", "battery": {"level": -1}}]}),  # off
    json.dumps({"devices": []}),                                               # no dongle
    "not json",
    "[]",
    '{"devices": [{"product": "G733", "battery": "60"}]}',
])
def test_off_or_odd_output_means_off(headset_watch, monkeypatch, output):
    fake_headsetcontrol(monkeypatch, headset_watch, output)
    assert not headset_watch.headset_on()


def test_headsetcontrol_missing_means_off(headset_watch, monkeypatch):
    def missing(*a, **k):
        raise FileNotFoundError("headsetcontrol")
    monkeypatch.setattr(headset_watch.subprocess, "run", missing)
    assert not headset_watch.headset_on()


def test_recolour_runs_rgb_sync_rescan_detached(headset_watch, monkeypatch):
    seen = []
    monkeypatch.setattr(headset_watch.subprocess, "Popen", lambda argv, **k: seen.append((argv, k)))
    headset_watch.recolour()
    argv, kwargs = seen[0]
    assert argv[0].endswith("bin/rgb-sync.sh") and argv[1:] == ["--rescan"]
    assert kwargs["start_new_session"]
