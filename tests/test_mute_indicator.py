"""Tests for lib/mute_indicator.py: wpctl and pactl are faked, so nothing
here reads or changes the real audio devices."""

import pytest

SINK_INSPECT = '''id 55, type PipeWire:Interface:Node
    alsa.card_name = "G733 Gaming Headset"
  * node.description = "G733 Gaming Headset Analog Stereo"
  * node.nick = "G733 Gaming Headset"
'''
SOURCE_INSPECT = '''id 60, type PipeWire:Interface:Node
    alsa.card_name = "HD-Audio Generic"
'''


@pytest.fixture
def audio(mute, monkeypatch):
    """What wpctl answers: get-volume per device, inspect per device. A device
    set to None does not exist (no microphone plugged in)."""
    answers = {mute.SINK: "Volume: 0.45", mute.SOURCE: "Volume: 0.82"}
    inspect = {mute.SINK: SINK_INSPECT, mute.SOURCE: SOURCE_INSPECT}

    def fake(cmd, device):
        if cmd == "get-volume":
            return answers[device] or ""
        return inspect[device]

    monkeypatch.setattr(mute, "wpctl", fake)
    return answers


def test_card_name_prefers_the_nick(mute):
    assert mute.card_name(SINK_INSPECT) == "G733 Gaming Headset"
    assert mute.card_name(SOURCE_INSPECT) == "HD-Audio Generic"
    assert mute.card_name("nothing here") == "Audio Device"


@pytest.mark.parametrize("output, level", [
    ("Volume: 0.45", (45, False)),
    ("Volume: 1.00 [MUTED]", (100, True)),
    ("", None),
])
def test_volume(mute, output, level):
    assert mute.volume(output) == level


def test_everything_on(mute, audio):
    state = mute.MuteIndicator().state()
    assert state["text"] == mute.SPEAKER
    assert state["class"] == []
    assert state["tooltip"] == ("Output: G733 Gaming Headset  45%\n"
                                "Microphone: HD-Audio Generic  82%\n"
                                "Click to expand audio")


def test_output_muted(mute, audio):
    audio[mute.SINK] = "Volume: 0.45 [MUTED]"
    state = mute.MuteIndicator().state()
    assert state["text"] == mute.SPEAKER_MUTED
    assert state["class"] == ["muted_active"]
    assert "Output: G733 Gaming Headset  45%  (muted)" in state["tooltip"]


def test_microphone_muted_shows_a_badge(mute, audio):
    audio[mute.SOURCE] = "Volume: 0.82 [MUTED]"
    state = mute.MuteIndicator().state()
    assert state["text"] == f"{mute.SPEAKER} {mute.MIC_MUTED}"
    assert state["class"] == ["mic-muted"]
    assert "Microphone: HD-Audio Generic  82%  (muted)" in state["tooltip"]


def test_both_muted(mute, audio):
    audio[mute.SINK] = "Volume: 0.45 [MUTED]"
    audio[mute.SOURCE] = "Volume: 0.82 [MUTED]"
    state = mute.MuteIndicator().state()
    assert state["text"] == f"{mute.SPEAKER_MUTED} {mute.MIC_MUTED}"
    assert state["class"] == ["muted_active", "mic-muted"]


def test_without_a_microphone_there_is_no_badge_and_no_mic_line(mute, audio):
    audio[mute.SOURCE] = None
    state = mute.MuteIndicator().state()
    assert state["text"] == mute.SPEAKER
    assert "Microphone" not in state["tooltip"]


def test_events_for_devices_and_the_server_only(mute, monkeypatch):
    monkeypatch.setattr(mute, "lines", lambda cmd: iter([
        "Event 'change' on sink #55\n",
        "Event 'change' on source #60\n",          # the microphone: now ours too
        "Event 'new' on sink-input #120\n",        # an app's stream: not ours
        "Event 'new' on source-output #121\n",     # an app recording: not ours
        "Event 'change' on server #0\n",           # default device changed
        "Event 'change' on client #33\n",
    ]))
    assert len(list(mute.MuteIndicator().events())) == 3
