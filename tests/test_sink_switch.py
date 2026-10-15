"""Tests for lib/sink-switch.py, the audio output switcher. Every command
(wpctl, pw-dump, pactl, qs) is faked, so nothing real is switched."""

import json
from pathlib import Path

import pytest

from conftest import load_script

DUMP = [
    {"id": 66, "type": "PipeWire:Interface:Node", "info": {"props": {
        "media.class": "Audio/Sink", "node.name": "alsa_output.pci.analog-stereo",
        "node.description": "Starship Analog Stereo", "node.nick": "ALC1220"}}},
    {"id": 67, "type": "PipeWire:Interface:Node", "info": {"props": {
        "media.class": "Audio/Sink", "node.name": "alsa_output.pci.hdmi-stereo",
        "node.description": "HDMI", "node.nick": "TV"}}},
    {"id": 99, "type": "PipeWire:Interface:Node", "info": {"props": {
        "media.class": "Audio/Source", "node.name": "alsa_input.mic"}}},  # not a sink
]
INSPECT = '  * node.name = "alsa_output.pci.analog-stereo"\n'  # the default is the analog one


@pytest.fixture
def ss(monkeypatch, tmp_path):
    module = load_script("sink-switch.py")
    monkeypatch.setattr(module, "CONFIG", str(tmp_path / "sink-switch.conf"))
    answered = []

    def fake_out(argv):
        answered.append(argv)
        if argv[:1] == ["pw-dump"]:
            return json.dumps(DUMP)
        if argv[:2] == ["wpctl", "inspect"]:
            return INSPECT
        return ""

    monkeypatch.setattr(module, "out", fake_out)
    module.answered = answered
    shown = []
    monkeypatch.setattr(module.osd, "show", lambda *a, **k: shown.append(a))
    module.shown = shown
    return module


class FakeMenu:
    def __init__(self, answer):
        self.answer, self.rows, self.prompt = answer, None, None

    def choose(self, prompt, rows, hint=""):
        self.prompt, self.rows = prompt, rows
        return self.answer


def test_sinks_are_read_from_pw_dump_and_the_default_flagged(ss):
    sinks = ss.sinks()
    assert [s.id for s in sinks] == [66, 67]           # the source is left out
    assert [s.label for s in sinks] == ["ALC1220", "TV"]
    assert [s.default for s in sinks] == [True, False]  # the default sorts first


def test_the_label_prefers_the_nick_then_the_description(ss):
    assert ss.Sink(1, "name", "desc", "nick").label == "nick"
    assert ss.Sink(1, "name", "desc", "").label == "desc"
    assert ss.Sink(1, "name", "", "").label == "name"


def test_exclusions_read_the_config(ss):
    Path(ss.CONFIG).write_text("# hide the TV\n\n  TV  \n69\n")
    assert ss.exclusions(ss.CONFIG) == ["tv", "69"]


def test_a_missing_config_hides_nothing(ss):
    assert ss.exclusions(ss.CONFIG) == []
    assert len(ss.visible(ss.CONFIG)) == 2


def test_without_a_config_argument_the_personal_one_is_read(ss):
    Path(ss.CONFIG).write_text("TV\n")
    assert [s.label for s in ss.visible()] == ["ALC1220"]


def test_a_pattern_matches_name_description_or_nick(ss):
    sink = ss.Sink(66, "alsa_output.pci.analog-stereo", "Starship Analog", "ALC1220")
    assert ss.hidden(sink, ["alc1220"]) is True   # the nick
    assert ss.hidden(sink, ["analog"]) is True    # the description
    assert ss.hidden(sink, ["pci"]) is True       # the name
    assert ss.hidden(sink, ["66"]) is False       # ids change on every boot


def test_a_number_matches_as_text(ss):
    sink = ss.Sink(66, "alsa_output.pci.analog-stereo", "Starship Analog", "ALC1220")
    assert ss.hidden(sink, ["1220"]) is True
    assert ss.hidden(sink, ["733"]) is False


def test_json_hides_the_excluded_and_flags_the_default(ss, capsys):
    Path(ss.CONFIG).write_text("TV\n")
    assert ss.main(config=ss.CONFIG, args=["--json"]) == 0
    assert json.loads(capsys.readouterr().out) == [
        {"id": 66, "label": "ALC1220", "default": True,
         "kind": "speaker", "icon": ss.ICONS["speaker"]}]


def test_the_kind_guesses_the_device_family(ss):
    assert ss.kind_of({"node.name": "alsa_output.usb-x",
                       "device.form-factor": "headset"}) == "headset"
    assert ss.kind_of({"node.name": "bluez_output.AC_12_34",
                       "device.bus": "bluetooth"}) == "bluetooth"
    assert ss.kind_of({"node.name": "alsa_output.pci.hdmi-stereo",
                       "device.profile.name": "hdmi-stereo"}) == "monitor"
    assert ss.kind_of({"node.name": "alsa_output.pci.analog-stereo",
                       "device.profile.name": "analog-stereo"}) == "speaker"


def test_the_icon_follows_the_kind_with_a_generic_fallback(ss):
    assert ss.Sink(1, "n", "d", "", kind="headset").icon == ss.ICONS["headset"]
    assert ss.Sink(1, "n", "d", "", kind="unknown").icon == ss.SPEAKER


def test_set_makes_the_sink_default_and_shows_the_osd(ss):
    assert ss.main(config=ss.CONFIG, args=["--set", "67"]) == 0
    assert ["wpctl", "set-default", "67"] in ss.answered
    # The TV is an HDMI sink: its own glyph, not the generic speaker.
    assert ss.shown == [(ss.ICONS["monitor"], "Audio output", "TV", -1)]


def test_set_without_sync_leaves_the_streams_alone(ss):
    ss.main(config=ss.CONFIG, args=["--set", "67", "--no-sync"])
    assert not any(a[:1] == ["pactl"] for a in ss.answered)


@pytest.mark.parametrize("args", [["--set", "999"], ["--set"], ["--set", "x"]])
def test_set_with_a_bad_id_does_nothing(ss, args):
    assert ss.main(config=ss.CONFIG, args=args) == 1
    assert not any(a[:2] == ["wpctl", "set-default"] for a in ss.answered)


def test_sync_moves_every_running_stream(ss, monkeypatch):
    monkeypatch.setattr(ss.shutil, "which", lambda name: "/usr/bin/pactl")

    def command(argv):
        ss.answered.append(argv)
        if argv[:3] == ["pactl", "list", "short"]:
            return "12\tsober\tpipewire\n34\tspotify\tpipewire\n"
        return ""

    monkeypatch.setattr(ss, "out", command)
    ss.sync_streams("alsa_output.pci.analog-stereo")
    moves = [a for a in ss.answered if a[:2] == ["pactl", "move-sink-input"]]
    assert moves == [["pactl", "move-sink-input", "12", "alsa_output.pci.analog-stereo"],
                     ["pactl", "move-sink-input", "34", "alsa_output.pci.analog-stereo"]]


def test_sync_is_a_no_op_without_pactl(ss, monkeypatch):
    monkeypatch.setattr(ss.shutil, "which", lambda name: None)
    ss.sync_streams("alsa_output.pci.analog-stereo")
    assert not any(a[:1] == ["pactl"] for a in ss.answered)


def test_toggle_opens_the_panel_when_it_is_running(ss, monkeypatch):
    monkeypatch.setattr(ss, "quickshell_open", lambda: True)
    picked = []
    monkeypatch.setattr(ss, "pick", lambda *a, **k: picked.append(1))
    assert ss.main(config=ss.CONFIG, args=["--toggle"]) == 0
    assert picked == []


def test_toggle_falls_back_to_the_menu(ss, monkeypatch):
    monkeypatch.setattr(ss, "quickshell_open", lambda: False)
    menu = FakeMenu(0)
    assert ss.main(menu=menu, config=ss.CONFIG, args=["--toggle"]) == 0
    assert menu.rows == ["ALC1220", "TV"]
    assert ["wpctl", "set-default", "66"] in ss.answered


def test_a_picked_sink_is_switched(ss):
    menu = FakeMenu(1)  # the TV
    assert ss.main(menu=menu, config=ss.CONFIG, args=[]) == 0
    assert menu.prompt == "Audio output"
    assert ["wpctl", "set-default", "67"] in ss.answered


@pytest.mark.parametrize("answer", [None, 7, -1])
def test_dismissing_the_menu_switches_nothing(ss, answer):
    assert ss.main(menu=FakeMenu(answer), config=ss.CONFIG, args=[]) == 1
    assert not any(a[:2] == ["wpctl", "set-default"] for a in ss.answered)


def test_without_sinks_the_menu_never_opens(ss, monkeypatch):
    monkeypatch.setattr(ss, "visible", lambda config=ss.CONFIG: [])
    menu = FakeMenu(0)
    assert ss.main(menu=menu, config=ss.CONFIG, args=[]) == 1
    assert menu.rows is None


def test_quickshell_open_is_false_when_qs_fails(ss, monkeypatch):
    def boom(*a, **k):
        raise OSError("no qs")
    monkeypatch.setattr(ss.subprocess, "run", boom)
    assert ss.quickshell_open() is False
