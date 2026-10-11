"""Tests for lib/help-binds-parse.py, the keybinding list behind Super+I."""

import re
from pathlib import Path

import pytest

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
        ("", "", "SUPER + Q", "Close, then (quit)"),
        ("", "resize", "h", "Shrink"),
    ]


def test_binds_without_a_description_are_left_out(help_binds):
    assert not any("X" in keys for _, _, keys, _ in help_binds.parse_binds(SAMPLE))


def test_gestures_read_as_fingers_and_motion(help_binds):
    assert help_binds.parse_gestures(SAMPLE) == [("GESTURES", "", "3 fingers swipe left/right", "Switch workspace")]


def test_every_described_bind_in_the_config_is_listed(help_binds):
    text = (HYPR / "keybindings.lua").read_text()
    parsed = sorted(desc for _, _, _, desc in help_binds.parse_binds(text))
    in_binds = sorted(re.findall(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', text))
    assert parsed == in_binds and len(parsed) > 20


def test_no_bind_in_the_config_is_missing_a_description(help_binds):
    # parse_binds drops a bind with no description instead of listing it blank,
    # so the omission is silent: the bind just never shows up in Super+I. Catch
    # it here rather than waiting for someone to notice the gap in the guide.
    text = (HYPR / "keybindings.lua").read_text()
    blind = []
    for _, call, _ in help_binds.calls(text, r"hl\.bind\("):
        inner = call[1:-1]
        args = help_binds.split_args(inner)
        if len(args) < 2 or re.search(r'description\s*=\s*"', inner):
            continue
        blind.append(help_binds.key_label(args[0]))
    assert not blind, f"binds invisible en Super+I: {blind}"


def test_a_key_built_in_a_loop_is_listed_as_its_range(help_binds):
    # The number is not in the text, so the guide has to take the bounds from
    # the loop. A bare "SUPER + i" would be the alternative, and tells a reader
    # nothing.
    text = ('for i = 1, 9 do\n'
            '    hl.bind(mainMod .. " + " .. i, x, { description = "Focus Workspace" })\n'
            'end\n')
    assert help_binds.parse_binds(text) == [("", "", "SUPER + 1-9", "Focus Workspace")]


def test_a_range_follows_its_loop_not_a_hardcoded_one(help_binds):
    text = ('for n = 2, 5 do\n'
            '    hl.bind(mainMod .. " + " .. n, x, { description = "d" })\n'
            'end\n')
    assert help_binds.parse_binds(text) == [("", "", "SUPER + 2-5", "d")]


def test_a_written_out_key_is_left_alone(help_binds):
    # A literal key still concatenates; only the loop's ends in a variable.
    assert help_binds.parse_binds(
        'hl.bind(mainMod .. " + SHIFT + I", x, { description = "Zoom In" })'
    ) == [("", "", "SUPER + SHIFT + I", "Zoom In")]


def test_an_escaped_backslash_ends_the_string(help_binds):
    assert help_binds.split_args(r'"a\\", 2') == [r'"a\\"', "2"]
    assert help_binds.split_args(r'"say \"hi\", ok", 3') == [r'"say \"hi\", ok"', "3"]


def test_an_unclosed_call_loses_only_its_own_line(help_binds):
    text = ('hl.bind(mainMod .. " + A", x, { description = "kept" })\n'
            'hl.bind(mainMod .. " + B", y, { description = "mid edit"\n')
    assert help_binds.parse_binds(text) == [("", "", "SUPER + A", "kept")]
    assert help_binds.parse_gestures('hl.gesture({ fingers = 3') == []
    assert help_binds.find_submap_spans('hl.define_submap("resize", function ()') == []


SECTIONS = """
-- =======
--  FOCUS
-- =======
hl.bind(mainMod .. " + left", x, { description = "Focus Left" })
hl.bind(mainMod .. " + H", x, { description = "Focus Left" })
-- =======
--  WORKSPACES
-- =======
hl.bind(mainMod .. " + ALT + right", x, { description = "Next" })
hl.bind(mainMod .. " + L", x, { description = "Next" })
"""


def test_each_bind_belongs_to_the_section_above_it(help_binds):
    sections = [row[0] for row in help_binds.parse_binds(SECTIONS)]
    assert sections == ["FOCUS", "FOCUS", "WORKSPACES", "WORKSPACES"]


def test_keys_doing_the_same_share_one_row(help_binds):
    assert help_binds.group(help_binds.parse_binds(SECTIONS)) == [
        ("FOCUS", "", "Super + ← / H", "Focus Left"),
        ("WORKSPACES", "", "Super + Alt + → / Super + L", "Next"),
    ]


def test_the_same_description_in_another_submap_stays_apart(help_binds):
    rows = [("S", "", "SUPER + F", "Fullscreen"), ("S", "winctl", "f", "Fullscreen")]
    assert len(help_binds.group(rows)) == 2


@pytest.mark.parametrize("raw, shown", [
    ("SUPER + SHIFT + left", "Super + Shift + ←"),
    ("SUPER + mouse_down", "Super + Scroll ↓"),
    ("SUPER + mouse:272", "Super + Left drag"),
    ("SUPER + Return", "Super + Enter"),
    ("SUPER + masculine", "Super + º"),
    ("XF86AudioRaiseVolume", "Audio Raise Volume"),
    ("h", "H"),
    ("SUPER + 1-9", "Super + 1-9"),
])
def test_keys_read_like_a_keyboard(help_binds, raw, shown):
    assert help_binds.pretty(raw) == shown


def test_gestures_on_three_and_four_fingers_share_one_row(help_binds):
    assert help_binds.merge_keys(["3 fingers swipe up", "4 fingers swipe up"]) == "3 / 4 fingers swipe up"


def test_the_real_config_has_a_section_for_every_bind(help_binds):
    text = (HYPR / "keybindings.lua").read_text()
    assert all(row[0] for row in help_binds.parse_binds(text))
