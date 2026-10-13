"""Tests for lib/power-profile.sh with a fake powerprofilesctl that keeps the
current profile in a file, and a fake notify-send. Nothing real changes."""

import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "power-profile.sh"

PPCTL = r'''
case "$1" in
    get)  cat "$T/current" ;;
    list) cur=$(cat "$T/current")
          for p in $(cat "$T/have"); do
              [ "$p" = "$cur" ] && printf '* %s:\n' "$p" || printf '  %s:\n' "$p"
              printf '    Driver:\tfake\n\n'
          done ;;
    set)  echo "$2" > "$T/current" ;;
esac
'''


@pytest.fixture
def profile(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in {"powerprofilesctl": PPCTL, "notify-send": 'printf "%s\\n" "$*" >> "$T/notes"',
                       "qs": "exit 255"}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    env = {**os.environ, "T": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}

    def run(current, have="performance balanced power-saver"):
        (tmp_path / "current").write_text(current + "\n")
        (tmp_path / "have").write_text(have)
        subprocess.run(["bash", str(SCRIPT)], env=env, check=True, timeout=10)
        notes = tmp_path / "notes"
        return (tmp_path / "current").read_text().strip(), notes.read_text() if notes.exists() else ""

    return run


@pytest.mark.parametrize("current, expected", [
    ("power-saver", "balanced"),
    ("balanced", "performance"),
    ("performance", "power-saver"),   # wraps around
])
def test_switches_to_the_next_profile_and_says_so(profile, current, expected):
    now, notes = profile(current)
    assert now == expected
    assert f"Power profile: {expected}" in notes


def test_a_missing_performance_profile_is_skipped(profile):
    assert profile("balanced", have="balanced power-saver")[0] == "power-saver"


def test_without_powerprofilesctl_it_does_nothing(tmp_path):
    (tmp_path / "empty").mkdir()
    env = {**os.environ, "PATH": str(tmp_path / "empty")}
    assert subprocess.run(["/usr/bin/bash", str(SCRIPT)], env=env, timeout=10).returncode == 0


def test_the_osd_shows_the_profile_when_quickshell_runs(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    fakes_files = {"powerprofilesctl": PPCTL, "qs": 'printf "%s\\n" "$*" >> "$T/osd"',
                   "notify-send": 'printf "%s\\n" "$*" >> "$T/notes"'}
    for name, body in fakes_files.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    env = {**os.environ, "T": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}
    (tmp_path / "current").write_text("balanced\n")
    (tmp_path / "have").write_text("performance balanced power-saver")
    subprocess.run(["bash", str(SCRIPT)], env=env, check=True, timeout=10)
    assert (tmp_path / "current").read_text().strip() == "performance"
    assert not (tmp_path / "notes").exists()   # the OSD took it, no notification
    assert (tmp_path / "osd").read_text().strip() == (
        "-c hyprflow ipc call osd level \U000F0425 Power profile performance -1")


def test_a_failed_switch_says_nothing(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    ppctl = PPCTL.replace('set)  echo "$2" > "$T/current" ;;', "set)  exit 1 ;;")
    for name, body in {"powerprofilesctl": ppctl, "qs": "exit 255",
                       "notify-send": 'printf "%s\\n" "$*" >> "$T/notes"'}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    (tmp_path / "current").write_text("balanced\n")
    (tmp_path / "have").write_text("performance balanced power-saver")
    env = {**os.environ, "T": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}
    assert subprocess.run(["bash", str(SCRIPT)], env=env, timeout=10).returncode == 1
    assert not (tmp_path / "notes").exists()
