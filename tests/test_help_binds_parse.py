"""Tests for lib/help-binds-parse.py, the keybinding list behind Super+I."""

import re
from pathlib import Path

HYPR = Path(__file__).resolve().parent.parent / "dotconfig" / "hypr"

SAMPLE = '''
local mainMod = "SUPER"
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close, then (quit)" })
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("echo 'a, b'"))
hl.define_submap("resize", function ()
    hl.bind("h", hl.dsp.window.resize({ x = -20, y = 0 }), { description = "Shrink" })
end)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace", description = "Switch workspace" })
'''


def test_binds_keep_their_description_and_submap(help_binds):
    assert help_binds.parse_binds(SAMPLE) == [
        ("", "SUPER + Q", "Close, then (quit)"),
        ("resize", "h", "Shrink"),
    ]


def test_binds_without_a_description_are_left_out(help_binds):
    assert not any("X" in mods for _, mods, _ in help_binds.parse_binds(SAMPLE))


def test_gestures_read_as_fingers_and_motion(help_binds):
    assert help_binds.parse_gestures(SAMPLE) == [("", "3 fingers swipe left/right", "Switch workspace")]


def test_every_described_bind_in_the_config_is_listed(help_binds):
    text = (HYPR / "keybindings.lua").read_text()
    parsed = sorted(desc for _, _, desc in help_binds.parse_binds(text))
    in_binds = sorted(re.findall(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', text))
    assert parsed == in_binds and len(parsed) > 20
