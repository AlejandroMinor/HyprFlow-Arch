"""Tests for lib/layout-picker.py: the layouts come from input:kb_layout and
switching moves the chosen one to the front with hyprctl eval (keyword() is
not allowed with a Lua config). Hyprland and the OSD are faked."""

import pytest

from conftest import load_script


@pytest.fixture
def picker(monkeypatch):
    module = load_script("layout-picker.py")
    module.declared = {"str": "es,us"}
    module.evals = []
    module.shown = []

    def query(*_):
        return dict(module.declared)

    def apply(code):
        module.evals.append(code)
        module.declared["str"] = code.split('kb_layout = "')[1].split('"')[0]

    monkeypatch.setattr(module.hyprland, "query", query)
    monkeypatch.setattr(module.hyprland, "eval_lua", apply)
    monkeypatch.setattr(module.osd, "show", lambda *args: module.shown.append(args))
    return module


class FakeMenu:
    def __init__(self, answer):
        self.answer, self.rows = answer, None

    def choose(self, prompt, rows, hint=""):
        self.rows = rows
        return self.answer


def test_declared_layouts_come_from_kb_layout(picker):
    assert picker.layouts() == ["es", "us"]
    assert picker.current() == "es"


def test_hyprland_not_answering_gives_no_layouts(picker, monkeypatch):
    def fails(*_):
        raise picker.hyprland.HyprlandError("no answer")
    monkeypatch.setattr(picker.hyprland, "query", fails)
    assert picker.layouts() == []
    assert picker.current() is None


def test_switching_moves_the_chosen_layout_first(picker):
    assert picker.switch("us") is True
    assert picker.evals == [f'hl.config({{ input = {{ kb_layout = "us,es" }} }})']
    assert picker.shown == [(picker.GLYPH, "Keyboard layout", "us", -1)]


def test_an_undeclared_layout_is_refused(picker):
    assert picker.switch("fr") is False
    assert picker.evals == []
    assert picker.shown == []


def test_a_failed_switch_does_not_show_the_osd(picker, monkeypatch):
    def fails(*_):
        raise picker.hyprland.HyprlandError("no answer")
    monkeypatch.setattr(picker.hyprland, "eval_lua", fails)
    assert picker.switch("us") is False
    assert picker.shown == []


def test_a_switch_hyprland_refused_is_not_reported(picker, monkeypatch):
    def applies_but_keeps(*args):
        picker.evals.append(args[0])
    monkeypatch.setattr(picker.hyprland, "eval_lua", applies_but_keeps)
    assert picker.switch("us") is False
    assert picker.shown == []


def test_state_prints_the_active_layout(picker, capsys):
    assert picker.main(["--state"]) == 0
    assert capsys.readouterr().out.strip() == "es"


def test_set_applies_directly(picker):
    assert picker.main(["--set", "us"]) == 0
    assert picker.evals == [f'hl.config({{ input = {{ kb_layout = "us,es" }} }})']


def test_set_with_an_undeclared_layout_refuses(picker):
    assert picker.main(["--set", "fr"]) == 1
    assert picker.evals == []


def test_picking_from_the_menu_switches_layout(picker):
    menu = FakeMenu(1)
    assert picker.main([], menu) == 0
    assert menu.rows == ["<b>es</b>   <span alpha='55%'>(active)</span>", "us"]
    assert picker.evals == [f'hl.config({{ input = {{ kb_layout = "us,es" }} }})']


@pytest.mark.parametrize("answer", [None, 7, -1])
def test_dismissing_or_a_stray_answer_switches_nothing(picker, answer):
    menu = FakeMenu(answer)
    assert picker.main([], menu) == 0
    assert picker.evals == []


def test_no_layouts_declared_prints_an_error(picker, monkeypatch, capsys):
    def fails(*_):
        raise picker.hyprland.HyprlandError("no answer")
    monkeypatch.setattr(picker.hyprland, "query", fails)
    assert picker.main([], FakeMenu(0)) == 1
    assert "input:kb_layout" in capsys.readouterr().err