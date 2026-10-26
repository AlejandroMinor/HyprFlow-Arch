"""Tests for lib/hyprflow/keyboard_rgb.py and lib/keyboard-rgb.py. The keyboard
is a fake that keeps the settings block in memory: never the real hidraw."""

import json
import sys

import pytest

from conftest import LIB, load_script

sys.path.insert(0, str(LIB))
from hyprflow import keyboard_rgb  # noqa: E402


class FakeKeyboard:
    """Answers 83 b6 with its block and stores what comes back with 03."""

    def __init__(self, effect=5, busy=0):
        self.block = bytearray(keyboard_rgb.BLOCK)
        self.block[0] = 6
        self.block[keyboard_rgb.EFFECT] = effect
        for n in range(1, 21):
            at = keyboard_rgb.TABLE + 2 * (n - 1)
            self.block[at], self.block[at + 1] = 7, 0x34
        self.asked = False
        self.busy = busy  # requests turned down before it answers
        self.writes = []

    def pair(self, n):
        at = keyboard_rgb.TABLE + 2 * (n - 1)
        return self.block[at], self.block[at + 1]

    def set_feature(self, data):
        data = bytearray(data)
        if self.busy:
            self.busy -= 1
            raise BrokenPipeError(32, "Broken pipe")
        if data[0] == 5:
            assert list(data) == [5, 0x83, 0xB6, 0, 0, 0]
            self.asked = True
        else:
            assert data[0] == 6 and data[1] == 0x03 and len(data) == keyboard_rgb.BLOCK
            self.writes.append(data)
            self.block = data

    def get_feature(self, report, size):
        assert report == 6 and size == keyboard_rgb.BLOCK and self.asked
        self.asked = False
        answer = bytearray(self.block)
        answer[1], answer[2] = 0x83, 0xB6
        return answer


@pytest.fixture
def cli(tmp_path, monkeypatch):
    module = load_script("keyboard-rgb.py")
    monkeypatch.setattr(module, "LAST", tmp_path / "led-color")
    monkeypatch.setattr(module, "LIGHTS_OFF", tmp_path / "led-off")
    monkeypatch.setattr(keyboard_rgb.time, "sleep", lambda s: None)
    module.root = tmp_path
    return module


@pytest.mark.parametrize("colour, index", [
    ("FF0000", 0), ("#FF1100", 0), ("FFF000", 1), ("00FF00", 2), ("00FFFF", 3),
    ("0000FF", 4), ("9000FF", 5), ("FF00FF", 5), ("FF00C0", 5), ("FFFFFF", 6), ("808080", 6),
    ("FF0028", 5), ("FF0060", 5), ("FF000F", 0),   # pinkish reds: purple; near pure red: red
])
def test_a_colour_becomes_the_nearest_of_the_palette(colour, index):
    assert keyboard_rgb.nearest(colour) == index


def test_a_theme_colour_lights_every_effect_at_full_brightness(cli):
    kb = FakeKeyboard(effect=5)
    kb.block[keyboard_rgb.TABLE + 2 * 3 + 1] = 0x10  # effect 4: slow, dim
    assert cli.main(["color", "0000FF"], kb) == 0
    assert kb.pair(5) == (4, 0x34)
    assert kb.pair(4) == (4, 0x14)   # the Fn keys may switch to it: its speed stays
    assert all(kb.pair(n) == (7, 0x34) for n in keyboard_rgb.OWN_COLOURS)
    assert kb.block[keyboard_rgb.EFFECT] == 5
    assert len(kb.writes) == 1


def test_off_darkens_every_effect_and_keeps_colour_and_speed(cli):
    kb = FakeKeyboard(effect=9)
    cli.main(["color", "00FF00"], kb)
    cli.main(["off"], kb)
    assert kb.pair(9) == (2, 0x30) and kb.pair(11) == (2, 0x30)
    assert kb.pair(3) == (7, 0x30)


def test_rainbow_is_multicolour(cli):
    kb = FakeKeyboard(effect=3)
    cli.main(["rainbow"], kb)
    assert kb.pair(3) == (7, 0x34)


def test_a_new_effect_takes_the_theme_colour(cli):
    (cli.root / "led-color").write_text("FF0000\n")
    kb = FakeKeyboard(effect=5)
    assert cli.main(["effect", "11"], kb) == 0
    assert kb.block[keyboard_rgb.EFFECT] == 11
    assert kb.pair(11) == (0, 0x34)


def test_a_new_effect_stays_dark_while_the_lights_are_off(cli):
    (cli.root / "led-color").write_text("FF0000\n")
    (cli.root / "led-off").touch()
    kb = FakeKeyboard()
    cli.main(["effect", "2"], kb)
    assert kb.pair(2) == (0, 0x30)


def test_without_a_cached_colour_a_new_effect_is_white(cli):
    kb = FakeKeyboard()
    cli.main(["effect", "1"], kb)
    assert kb.pair(1)[0] == 6


def test_an_effect_out_of_range_is_refused_untouched(cli, capsys):
    kb = FakeKeyboard()
    assert cli.main(["effect", "21"], kb) == 1
    assert kb.writes == []


def test_json_lists_the_effects_with_the_one_in_use(cli, capsys):
    (cli.root / "led-color").write_text("00FF33\n")
    cli.main(["--json"], FakeKeyboard(effect=4))
    answer = json.loads(capsys.readouterr().out)
    assert answer["color"] == "#00FF00"   # the palette's, not the theme's own
    effects = answer["effects"]
    assert len(effects) == 20
    assert effects[3] == {"number": 4, "name": "Typed keys", "current": True}
    assert [e["number"] for e in effects if e["current"]] == [4]


def test_an_answer_from_another_page_is_never_written_back(cli):
    kb = FakeKeyboard()
    answer = kb.get_feature

    def other_page(report, size):
        block = answer(report, size)
        block[2] = 0xB8
        return block

    kb.get_feature = other_page
    assert cli.main(["off"], kb) == 1
    assert kb.writes == []


def test_a_busy_keyboard_is_asked_again(cli):
    kb = FakeKeyboard(busy=2)
    assert cli.main(["off"], kb) == 0
    assert len(kb.writes) == 1


def test_a_keyboard_that_stays_busy_fails_without_writing(cli, capsys):
    kb = FakeKeyboard(busy=50)
    assert cli.main(["off"], kb) == 1
    assert kb.writes == []


def test_without_the_keyboard_nothing_happens(cli, monkeypatch, capsys):
    monkeypatch.setattr(keyboard_rgb, "find", lambda: None)
    assert cli.main(["color", "FF0000"]) == 0
    assert cli.main(["--json"]) == 0
    assert json.loads(capsys.readouterr().out) == {"effects": []}


def test_unknown_arguments_show_the_usage(cli, capsys):
    assert cli.main(["blink"], FakeKeyboard()) == 2
    assert "keyboard-rgb.py color" in capsys.readouterr().err


def node(sysfs, name, hid_id, descriptor):
    device = sysfs / name / "device"
    device.mkdir(parents=True)
    (device / "uevent").write_text(f"DRIVER=hid-generic\nHID_ID={hid_id}\nHID_NAME=x\n")
    (device / "report_descriptor").write_bytes(descriptor)


def test_find_picks_the_control_interface(tmp_path):
    node(tmp_path, "hidraw3", "0003:0000046D:0000C548", b"\x85\x06")
    node(tmp_path, "hidraw11", "0003:0000258A:00000049", b"\x05\x01\x09\x06")
    node(tmp_path, "hidraw12", "0003:0000258A:00000049", b"\x85\x05\x00\x85\x06")
    assert keyboard_rgb.find(tmp_path) == "/dev/hidraw12"


def test_find_without_the_keyboard(tmp_path):
    node(tmp_path, "hidraw0", "0003:00001532:00000099", b"\x85\x06")
    assert keyboard_rgb.find(tmp_path) is None
