"""Tests for lib/brightness.sh with a fake brightnessctl that keeps its own
level in a file, a fake notify-send and a fake Quickshell panel, so no real
backlight changes and no real panel opens."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "brightness.sh"

BRIGHTNESSCTL = r'''
dev="$T/level"
case "$1" in
    set)
        step="${2}"; cur="$(cat "$dev")"
        awk -v c="$cur" -v s="${step%%%*}" -v sign="${step: -1}" \
            'BEGIN { v = (sign == "+") ? c + s : c - s; if (v < 0) v = 0; if (v > 100) v = 100; printf "%d", v }' > "$dev" ;;
    -m) printf 'intel_backlight,backlight,500,%s%%,1000\n' "$(cat "$dev")" ;;
esac
'''

# The Quickshell panel: logs how it was called and succeeds, or is not running
# (exit 255) when FAKE_OSD is unset.
QS = r'''
[ -n "${FAKE_OSD+x}" ] || exit 255
printf '%s\n' "$@" >> "$T/osd"
'''


@pytest.fixture
def bright(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in {"brightnessctl": BRIGHTNESSCTL,
                       "notify-send": 'printf "%s\\n" "$*" >> "$T/notes"',
                       "qs": QS}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    (tmp_path / "level").write_text("45")
    env = {**os.environ, "T": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}

    def run(*args, **extra):
        result = subprocess.run(["bash", str(SCRIPT), *args], env={**env, **extra},
                                text=True, capture_output=True, timeout=10)
        notes = tmp_path / "notes"
        last = notes.read_text().splitlines()[-1] if notes.exists() else None
        return result, last

    return run, tmp_path


def osd_args(root):
    log = root / "osd"
    return log.read_text().splitlines() if log.exists() else []


def test_up_raises_and_shows_the_new_level(bright):
    run, root = bright
    _, note = run("up")
    assert (root / "level").read_text() == "55"
    assert note.endswith("Brightness 55%")


def test_down_lowers(bright):
    run, root = bright
    run("down")
    assert (root / "level").read_text() == "35"


def test_the_level_is_clamped(bright):
    run, root = bright
    (root / "level").write_text("95")
    run("up")
    assert (root / "level").read_text() == "100"
    (root / "level").write_text("5")
    run("down")
    assert (root / "level").read_text() == "0"


# The Quickshell OSD (Osd.qml): qs answers, so no notification is shown.
# The args after "osd level" are ICON TITLE CAPTION VALUE.

def test_the_osd_shows_the_level_when_quickshell_runs(bright):
    run, root = bright
    _, note = run("up", FAKE_OSD="1")
    assert note is None                                        # notification skipped
    args = osd_args(root)
    assert args[4:6] == ["osd", "level"]
    assert args[6] == chr(0xF00E0)                             # the brighter glyph
    assert args[7] == "Brightness" and args[8] == "55%" and args[9] == "55"


def test_the_osd_uses_the_dimmer_glyph_going_down(bright):
    run, root = bright
    run("down", FAKE_OSD="1")
    assert osd_args(root)[6] == chr(0xF00DD)


def test_without_quickshell_it_falls_back_to_a_notification(bright):
    run, root = bright
    _, note = run("up")                                        # qs exits 255
    assert note.endswith("Brightness 55%")
    assert osd_args(root) == []


def test_unknown_action(bright):
    run, _ = bright
    result, _ = run("sideways")
    assert result.returncode == 1 and "usage" in result.stderr


def test_without_brightnessctl_it_stays_quiet(bright, tmp_path):
    _, root = bright
    # A PATH with the tools brightness.sh needs, but no brightnessctl: the
    # guard stops before touching a real backlight.
    tools = tmp_path / "tools"
    tools.mkdir()
    for tool in ("dirname", "readlink", "cut"):
        (tools / tool).symlink_to(shutil.which(tool))
    env = {**os.environ, "T": str(root), "PATH": str(tools)}
    result = subprocess.run([shutil.which("bash"), str(SCRIPT), "up"], env=env,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 0
    assert result.stdout == "" and result.stderr == ""
    assert not (root / "notes").exists()
