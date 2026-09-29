"""Tests for lib/quick-actions.py, the Super+K menu. A fake menu picks, and
subprocess.Popen is caught, so nothing real is switched."""

from pathlib import Path

import pytest

from conftest import load_script


@pytest.fixture
def qa(monkeypatch):
    module = load_script("quick-actions.py")
    launched = []
    monkeypatch.setattr(module.subprocess, "Popen", lambda argv, **k: launched.append((argv, k)))
    module.launched = launched
    return module


class FakeMenu:
    def __init__(self, answer):
        self.answer, self.rows = answer, None

    def choose(self, prompt, rows, hint=""):
        self.rows = rows
        return self.answer


def test_a_switch_shows_its_state_and_an_action_does_not(qa):
    assert qa.Action("x", "Lights", ["true"], lambda: True).row().endswith(">on</span>")
    assert qa.Action("x", "Lights", ["true"], lambda: False).row().endswith(">off</span>")
    assert qa.Action("x", "Wallpaper", ["true"]).row() == "x  Wallpaper"
    assert qa.Action("x", "Mirror", ["true"], lambda: None).row() == "x  Mirror"   # unknown


def test_the_picked_action_runs_detached(qa):
    actions = [qa.Action("a", "First", ["one"]), qa.Action("b", "Second", ["two", Path("/x")])]
    menu = FakeMenu(1)
    qa.main(menu, actions)
    assert menu.rows == ["a  First", "b  Second"]
    (argv, options), = qa.launched
    assert argv == ["two", "/x"] and options["start_new_session"]


@pytest.mark.parametrize("answer", [None, 7, -1])
def test_dismissing_or_a_stray_answer_runs_nothing(qa, answer):
    qa.main(FakeMenu(answer), [qa.Action("a", "Only", ["one"])])
    assert qa.launched == []


def test_every_script_an_action_runs_is_in_the_repo(qa):
    scripts = [part for action in qa.ACTIONS for part in action.argv if isinstance(part, Path)]
    assert scripts
    for script in scripts:
        assert script.exists(), script


def test_states_read_their_files(qa, monkeypatch, tmp_path):
    monkeypatch.setattr(qa.paths, "HYPRFLOW_STATE", tmp_path / "state")
    monkeypatch.setattr(qa.paths, "CACHE", tmp_path / "cache")
    assert qa.game_mode_on() is False and qa.lights_on() is True
    (tmp_path / "state").mkdir()
    (tmp_path / "state" / "game-mode").write_text("solo=1\n")
    (tmp_path / "cache" / "wallust").mkdir(parents=True)
    (tmp_path / "cache" / "wallust" / "led-off").write_text("")
    assert qa.game_mode_on() is True and qa.lights_on() is False


def test_mirror_state_is_unknown_without_hyprland(qa, monkeypatch):
    import monitors

    def fails():
        raise monitors.hyprland.HyprlandError("no answer")
    monkeypatch.setattr(monitors, "detect", fails)
    assert qa.mirror_on() is None
