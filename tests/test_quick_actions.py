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


def test_keyboard_layout_action_runs_the_picker(qa):
    action = next(a for a in qa.ACTIONS if a.label == "Keyboard layout")
    assert action.argv == [qa.LIB / "layout-picker.py"]


def test_keyboard_layout_state_reads_the_active_layout(qa, monkeypatch):
    monkeypatch.setattr(qa, "output", lambda argv: "es")
    assert qa.current_layout() == "es"


def test_keyboard_layout_state_unknown_without_hyprland(qa, monkeypatch):
    monkeypatch.setattr(qa, "output", lambda argv: "")
    assert qa.current_layout() is None


def test_json_lists_the_shown_actions_with_their_state(qa, capsys, monkeypatch):
    monkeypatch.setattr(qa.shutil, "which", lambda name: None)
    qa.main(actions=[qa.Action("a", "Lights", ["one"], lambda: False),
                     qa.Action("b", "Gone", ["two"], needs="missing"),
                     qa.Action("c", "Power", ["three"], lambda: "balanced")], args=["--json"])
    import json
    assert json.loads(capsys.readouterr().out) == [
        {"icon": "a", "label": "Lights", "state": "off", "section": ""},
        {"icon": "c", "label": "Power", "state": "balanced", "section": ""},
    ]
    assert qa.launched == []


def test_actions_are_grouped_under_their_section_heading(qa, monkeypatch):
    monkeypatch.setattr(qa.shutil, "which", lambda name: "/usr/bin/" + name)
    actions = [qa.Action("a", "Mic", ["one"], section="Audio"),
               qa.Action("b", "Mirror", ["two"], section="Screens"),
               qa.Action("c", "Output", ["three"], section="Audio")]
    rows, targets = qa.grouped(qa.ordered(actions))
    assert rows == ["<b>Screens</b>", "b  Mirror", "<b>Audio</b>", "a  Mic", "c  Output"]
    assert [None if t is None else t.label for t in targets] == \
        [None, "Mirror", None, "Mic", "Output"]


def test_a_section_heading_picking_runs_nothing(qa, monkeypatch):
    monkeypatch.setattr(qa.shutil, "which", lambda name: "/usr/bin/" + name)
    qa.main(FakeMenu(0), [qa.Action("a", "Mic", ["one"], section="Audio")])
    assert qa.launched == []


def test_picking_a_row_runs_its_action_past_the_headings(qa, monkeypatch):
    monkeypatch.setattr(qa.shutil, "which", lambda name: "/usr/bin/" + name)
    actions = [qa.Action("a", "Mirror", ["one"], section="Screens"),
               qa.Action("b", "Mic", ["two"], section="Audio")]
    qa.main(FakeMenu(3), actions)              # Screens, Mirror, Audio, Mic
    assert [argv for argv, _ in qa.launched] == [["two"]]


def test_run_picks_an_action_by_its_label(qa):
    actions = [qa.Action("a", "First", ["one"]), qa.Action("b", "Second", ["two"])]
    assert qa.main(actions=actions, args=["--run", "Second"]) == 0
    assert qa.launched[0][0] == ["two"]


@pytest.mark.parametrize("args", [["--run", "Nope"], ["--run"]])
def test_run_with_an_unknown_label_runs_nothing(qa, args):
    assert qa.main(actions=[qa.Action("a", "First", ["one"])], args=args) == 1
    assert qa.launched == []


def test_power_menu_action_opens_the_quickshell_panel(qa):
    action = next(a for a in qa.ACTIONS if a.label == "Power menu")
    assert action.argv == ["qs", "-c", "hyprflow", "ipc", "call", "power", "toggle"]
    assert action.section == "System"


def test_spectrum_style_reads_its_file(qa, monkeypatch, tmp_path):
    monkeypatch.setattr(qa.paths, "HYPRFLOW_STATE", tmp_path)
    assert qa.spectrum_style() == "bars"            # never picked
    (tmp_path / "cava-style").write_text("leds\n")
    assert qa.spectrum_style() == "leds"
