"""Tests for lib/media.sh: a fake playerctl and a fake qs, so nothing plays
and no OSD is really shown."""

import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "media.sh"


@pytest.fixture
def media(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in {"playerctl": 'printf "%s\\n" "$*" >> "$T/played"',
                       "qs": 'printf "%s\\n" "$*" >> "$T/osd"'}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    env = {**os.environ, "T": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}

    def run(action, player=True):
        if not player:
            (fakes / "playerctl").write_text("#!/bin/bash\nexit 1\n")
        subprocess.run(["bash", str(SCRIPT), action], env=env, check=True, timeout=10)
        osd = (tmp_path / "osd").read_text().splitlines() if (tmp_path / "osd").exists() else []
        played = (tmp_path / "played").read_text().splitlines() if (tmp_path / "played").exists() else []
        return osd, played

    return run


def test_next_shows_the_next_glyph(media):
    osd, played = media("next")
    assert played == ["next"]
    assert osd == ["-c hyprflow ipc call osd level \U000F04AD Media Next -1"]


def test_previous_shows_the_previous_glyph(media):
    osd, played = media("previous")
    assert played == ["previous"]
    assert osd == ["-c hyprflow ipc call osd level \U000F04AE Media Previous -1"]


def test_without_a_player_nothing_is_shown(media):
    osd, played = media("next", player=False)
    assert played == [] and osd == []


def test_an_unknown_action_does_nothing(media):
    osd, played = media("play-pause")
    assert played == [] and osd == []
