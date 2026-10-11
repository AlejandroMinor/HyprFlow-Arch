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


def test_a_state_word_is_shown_as_is(qa):
    assert qa.Action("x", "Power", ["true"], lambda: "balanced").row().endswith(">balanced</span>")


def test_actions_whose_program_is_missing_are_left_out(qa, monkeypatch):
    monkeypatch.setattr(qa.shutil, "which", lambda name: None if name == "missing" else "/usr/bin/" + name)
    menu = FakeMenu(None)
    qa.main(menu, [qa.Action("a", "Here", ["one"], needs="present"),
                   qa.Action("b", "Gone", ["two"], needs="missing"),
                   qa.Action("c", "Plain", ["three"])])
    assert menu.rows == ["a  Here", "c  Plain"]


def test_a_picked_action_is_counted_among_the_shown_ones(qa, monkeypatch):
    monkeypatch.setattr(qa.shutil, "which", lambda name: None)
    qa.main(FakeMenu(1), [qa.Action("a", "Gone", ["one"], needs="missing"),
                          qa.Action("b", "First", ["two"]), qa.Action("c", "Second", ["three"])])
    assert qa.launched[0][0] == ["three"]


@pytest.mark.parametrize("out, expected", [("true", True), ("false", False), ("", None)])
def test_dnd_state(qa, monkeypatch, out, expected):
    monkeypatch.setattr(qa, "output", lambda argv: out)
    assert qa.dnd_on() is expected


@pytest.mark.parametrize("out, expected", [
    ("Volume: 0.82", True), ("Volume: 0.82 [MUTED]", False), ("", None)])
def test_mic_state(qa, monkeypatch, out, expected):
    monkeypatch.setattr(qa, "output", lambda argv: out)
    assert qa.mic_on() is expected


def test_power_profile_state(qa, monkeypatch):
    monkeypatch.setattr(qa, "output", lambda argv: "balanced")
    assert qa.power_profile() == "balanced"
    monkeypatch.setattr(qa, "output", lambda argv: "")
    assert qa.power_profile() is None
