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


@pytest.mark.parametrize("report, expected", [
    ("11ff08000f150100", True),    # battery notice: turned on
    ("11ff080000000000", True),    # battery notice: turned off
    ("11ff080a0f030100", False),   # reply to headsetcontrol (software id 0xa)
    ("11ff000103000000", False),   # reply to OpenRGB (software id 1)
    ("0800", False),               # the mic mute button
    ("", False),
])
def test_only_unasked_hidpp_reports_wake_it(headset_watch, report, expected):
    assert headset_watch.notification(bytes.fromhex(report)) is expected


def test_hidraws_finds_the_headset_by_its_ids(headset_watch, tmp_path):
    for name, hid_id in [("hidraw4", "0003:0000046D:00000AB5"), ("hidraw7", "0003:00001532:00000099")]:
        (tmp_path / name / "device").mkdir(parents=True)
        (tmp_path / name / "device" / "uevent").write_text(f"DRIVER=hid-generic\nHID_ID={hid_id}\n")
    assert headset_watch.hidraws(0x046D, 0x0AB5, tmp_path) == ["/dev/hidraw4"]


def test_headset_ids_come_from_headsetcontrol(headset_watch, monkeypatch):
    fake_headsetcontrol(monkeypatch, headset_watch, json.dumps(
        {"devices": [{"product": "G733", "id_vendor": "0x046d", "id_product": "0x0ab5"}]}))
    assert headset_watch.headset_ids() == (0x046D, 0x0AB5)
    fake_headsetcontrol(monkeypatch, headset_watch, json.dumps({"devices": []}))
    assert headset_watch.headset_ids() is None
