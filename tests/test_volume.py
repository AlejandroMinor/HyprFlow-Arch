"""Tests for lib/volume.sh with a fake wpctl that keeps its own volume and
mute state in files, and a fake notify-send, so no real device changes."""

import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "volume.sh"

WPCTL = r'''
dev="$T/$( [[ "$*" == *SOURCE* ]] && echo source || echo sink )"
case "$1" in
    get-volume)
        [ -f "$dev.vol" ] || exit 1
        printf 'Volume: %s%s\n' "$(cat "$dev.vol")" "$( [ -f "$dev.muted" ] && echo ' [MUTED]')" ;;
    set-mute)
        if [ -f "$dev.muted" ]; then rm "$dev.muted"; else touch "$dev.muted"; fi ;;
    set-volume)
        step="${@: -1}"; cur="$(cat "$dev.vol")"
        awk -v c="$cur" -v s="${step%%%*}" -v sign="${step: -1}" \
            'BEGIN { v = (sign == "+") ? c + s / 100 : c - s / 100; if (v < 0) v = 0; if (v > 1) v = 1; printf "%.2f", v }' > "$dev.vol" ;;
esac
'''


@pytest.fixture
def vol(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in {"wpctl": WPCTL, "notify-send": 'printf "%s\\n" "$*" >> "$T/notes"'}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    (tmp_path / "sink.vol").write_text("0.45")
    (tmp_path / "source.vol").write_text("0.82")
    env = {**os.environ, "T": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}

    def run(*args):
        result = subprocess.run(["bash", str(SCRIPT), *args], env=env, text=True,
                                capture_output=True, timeout=10)
        notes = tmp_path / "notes"
        last = notes.read_text().splitlines()[-1] if notes.exists() else None
        return result, last

    return run, tmp_path


def test_up_raises_and_shows_the_new_level(vol):
    run, root = vol
    _, note = run("up")
    assert (root / "sink.vol").read_text() == "0.50"
    assert "int:value:50" in note and note.endswith("Volume 50%")
    assert "audio-volume-medium-symbolic" in note


def test_the_notification_replaces_the_last_and_skips_the_center(vol):
    run, _ = vol
    _, note = run("down")
    assert "-e" in note.split() and "string:x-canonical-private-synchronous:volume" in note


def test_mute_shows_muted_at_zero(vol):
    run, root = vol
    _, note = run("mute")
    assert (root / "sink.muted").exists()
    assert "int:value:0" in note and note.endswith("Volume Muted")
    run("mute")
    assert not (root / "sink.muted").exists()


def test_mic_mute_touches_only_the_microphone(vol):
    run, root = vol
    _, note = run("mic-mute")
    assert (root / "source.muted").exists() and not (root / "sink.muted").exists()
    assert note.endswith("Microphone Muted")
    _, note = run("mic-mute")
    assert note.endswith("Microphone On  ·  82%")


def test_low_and_high_icons(vol):
    run, root = vol
    (root / "sink.vol").write_text("0.10")
    assert "audio-volume-low-symbolic" in run("down")[1]
    (root / "sink.vol").write_text("0.90")
    assert "audio-volume-high-symbolic" in run("up")[1]


def test_without_a_device_it_stays_quiet(vol):
    run, root = vol
    (root / "source.vol").unlink()
    result, note = run("mic-mute")
    assert result.returncode == 0 and note is None


def test_unknown_action(vol):
    run, _ = vol
    result, _ = run("louder")
    assert result.returncode == 1 and "usage" in result.stderr
