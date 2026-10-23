"""Tests for lib/activate-linux.py, the GTK watermark. The surface itself
needs a compositor; what matters without one is the single instance guard."""

import fcntl
import os
import subprocess
import sys
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "activate-linux.py"


def test_a_second_copy_exits_at_once(tmp_path):
    with open(tmp_path / "activate-linux.lock", "w") as held:
        fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)      # the first copy
        result = subprocess.run([sys.executable, str(SCRIPT)], timeout=20,
                                env={**os.environ, "XDG_RUNTIME_DIR": str(tmp_path)},
                                capture_output=True, text=True)
    assert result.returncode == 0


def test_it_reads_like_the_real_thing():
    text = SCRIPT.read_text()
    assert 'TITLE = "Activate Linux"' in text
    assert 'SUBTITLE = "Go to Settings to activate Linux"' in text


class Monitor:
    def __init__(self, connector):
        self.connector = connector

    def get_connector(self):
        return self.connector


def test_it_goes_where_workspace_1_is_and_hides_in_game_mode_or_when_off():
    from conftest import load_script
    target = load_script("activate-linux.py").target
    big, tv = Monitor("DP-2"), Monitor("HDMI-A-1")
    assert target([tv, big], "DP-2", hidden=False) is big
    assert target([tv, big], "DP-9", hidden=False) is tv      # workspace 1 not found yet
    assert target([tv, big], "HDMI-A-1", hidden=True) is None
    assert target([], "DP-2", hidden=False) is None


def test_without_hyprland_it_falls_back_to_the_first_monitor(monkeypatch):
    from conftest import load_script
    module = load_script("activate-linux.py")

    def fails(*what):
        raise module.hyprland.HyprlandError("hyprctl workspaces: no answer")

    monkeypatch.setattr(module.hyprland, "query", fails)
    assert module.primary_port() is None
    assert module.target([Monitor("DP-2")], module.primary_port(), hidden=False).get_connector() == "DP-2"


@pytest.mark.parametrize("script", ["activate-linux.py", "master-pick.py"])
def test_without_gtk4_layer_shell_it_says_what_to_install(monkeypatch, script):
    import ctypes
    from conftest import load_script

    def missing(name, *a, **k):
        raise OSError(f"{name}: cannot open shared object file")

    monkeypatch.setattr(ctypes, "CDLL", missing)
    with pytest.raises(SystemExit, match="gtk4-layer-shell"):
        load_script(script)


def test_toggle_flips_the_off_marker(monkeypatch, tmp_path):
    from conftest import load_script
    module = load_script("activate-linux.py")
    monkeypatch.setattr(module, "OFF", tmp_path / "hyprflow" / "watermark-off")
    assert module.main(["--toggle"]) == 0 and module.OFF.exists()
    assert module.main(["--toggle"]) == 0 and not module.OFF.exists()
