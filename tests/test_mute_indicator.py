"""Tests for bin/mute_indicator.py: wpctl and pactl are faked."""

import pytest

INSPECT = '''id 55, type PipeWire:Interface:Node
  * alsa.card_name = "HD-Audio Generic"
    alsa.driver_name = "snd_hda_intel"
'''


@pytest.fixture
def wpctl(mute, monkeypatch):
    """Answers get-volume with `volume`; inspect with INSPECT."""
    answers = {"volume": "Volume: 0.40"}

    def fake(*args):
        return answers["volume"] if args[0] == "get-volume" else INSPECT

    monkeypatch.setattr(mute, "wpctl", fake)
    return answers


def test_card_name_from_inspect(mute):
    assert mute.card_name(INSPECT) == "HD-Audio Generic"
    assert mute.card_name("no card here") == "Audio Device"


def test_unmuted(mute, wpctl):
    assert mute.MuteIndicator().state() == {
        "text": "󰕾", "class": "", "tooltip": "Click to expand audio"}


def test_muted_names_the_card(mute, wpctl):
    wpctl["volume"] = "Volume: 0.40 [MUTED]"
    state = mute.MuteIndicator().state()
    assert state["class"] == "muted_active"
    assert state["text"] == "󰖁"
    assert state["tooltip"] == "HD-Audio Generic is muted"


def test_events_only_for_sinks_and_the_server(mute, monkeypatch):
    monkeypatch.setattr(mute, "lines", lambda cmd: iter([
        "Event 'change' on sink #55\n",
        "Event 'change' on source #60\n",          # a microphone: not ours
        "Event 'new' on sink-input #120\n",        # an app's stream: not ours
        "Event 'change' on server #0\n",           # default device changed
        "Event 'change' on client #33\n",
    ]))
    assert len(list(mute.MuteIndicator().events())) == 2
