"""lib/appearance.py with every path in tmp and fake hyprctl and swaync-client
that only log: nothing real reloads. Also that the repo's starting colours
are the first tone's, and every panel gets the glass."""

import json
import os
import re
import subprocess
from pathlib import Path

import pytest

from conftest import load_script

REPO = Path(__file__).resolve().parent.parent
DOTCONFIG = REPO / "dotconfig"
PALETTES = DOTCONFIG / "quickshell" / "hyprflow" / "palettes.json"


@pytest.fixture
def app(tmp_path, monkeypatch):
    module = load_script("appearance.py")
    for name, path in {"STATE": tmp_path / "state" / "appearance.json",
                       "GLASS": tmp_path / "state" / "glass.lua",
                       "ROFI": tmp_path / "rofi" / "colors.rasi",
                       "SWAYNC": tmp_path / "swaync" / "colors.css"}.items():
        monkeypatch.setattr(module, name, path)
    monkeypatch.setattr(module, "PALETTES", PALETTES)
    monkeypatch.setattr(module, "WALLUST", tmp_path / "colors-rofi-sh.conf")
    monkeypatch.setattr(module, "LED", tmp_path / "led-color")
    (tmp_path / "rofi").mkdir()
    (tmp_path / "swaync").mkdir()
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name in ("hyprctl", "swaync-client"):
        (fakes / name).write_text(f'#!/bin/bash\necho "{name} $*" >> "{tmp_path}/calls"\n')
        (fakes / name).chmod(0o755)
    monkeypatch.setenv("PATH", f"{fakes}:{os.environ['PATH']}")
    module.calls = lambda: (tmp_path / "calls").read_text() if (tmp_path / "calls").exists() else ""
    module.saved = lambda: json.loads(module.STATE.read_text())
    return module


def test_a_tone_writes_rofi_swaync_and_the_glass(app):
    assert app.main(["tone", "light"]) == 0
    assert app.saved()["tone"] == "light"
    assert "bg-window:  #FFFFFFA6;" in app.ROFI.read_text()
    assert "--text-color: #3C3C43;" in app.SWAYNC.read_text()
    assert "brightness    = 1.5" in app.GLASS.read_text()
    assert "swaync-client -rs" in app.calls() and "hyprctl reload" in app.calls()


def test_glass_off_keeps_plain_blur_for_every_tone(app):
    app.main(["tone", "light"])
    assert app.main(["glass", "off"]) == 0
    assert app.saved()["glass"] is False
    assert app.GLASS.read_text().endswith("return false\n")
    app.main(["tone", "slate"])
    assert "return false" in app.GLASS.read_text()
    app.main(["glass", "on"])
    assert "blur_strength" in app.GLASS.read_text()


def test_nothing_changed_reloads_nothing(app):
    app.main(["tone", "slate"])
    (app.GLASS.parent.parent / "calls").unlink()
    app.main(["apply"])
    assert app.calls() == ""


def test_next_goes_round_the_tones(app):
    names = list(json.loads(PALETTES.read_text()))
    seen = []
    for _ in names:
        app.main(["next"])
        seen.append(app.saved()["tone"])
    assert seen == names[1:] + names[:1]


def test_tweaks_are_kept_per_tone_and_clamped(app):
    app.main(["tone", "slate"])
    app.main(["set", "card", "0.5"])
    app.main(["set", "blur", "9"])
    assert app.saved()["slate"] == {"card": 0.5, "blur": 4.0}
    assert "bg-window:  #1B1F2680;" in app.ROFI.read_text()
    assert "blur_strength = 4" in app.GLASS.read_text()

    app.main(["tone", "black"])
    assert "bg-window:  #00000061;" in app.ROFI.read_text()
    app.main(["tone", "slate"])
    assert "bg-window:  #1B1F2680;" in app.ROFI.read_text()

    app.main(["reset"])
    assert "slate" not in app.saved()


def test_the_theme_tone_takes_wallust_and_the_led_colour(app, tmp_path):
    (tmp_path / "colors-rofi-sh.conf").write_text("background='#040401'\nforeground='#ffc071'\ncolor5='#7c7870'\n")
    app.main(["tone", "theme"])
    css = app.SWAYNC.read_text()
    assert "--text-color: #FFC071;" in css and "--bg-selected: #7C7870;" in css
    assert "bg-solid:   #040401;" in app.ROFI.read_text()
    (tmp_path / "led-color").write_text("ff8800\n")
    app.main(["apply"])
    assert "--bg-selected: #FF8800;" in app.SWAYNC.read_text()


def test_the_theme_tone_without_wallust_keeps_its_own_colours(app):
    app.main(["tone", "theme"])
    assert "--text-color: #FFFFFF;" in app.SWAYNC.read_text()


def test_the_text_colour_is_a_tweak_too(app):
    app.main(["tone", "light"])
    app.main(["set", "text", "#ffffff"])
    assert app.saved()["light"] == {"text": "#FFFFFF"}
    assert "foreground: #FFFFFF;" in app.ROFI.read_text()
    app.main(["set", "text", "default"])
    assert app.saved()["light"] == {}
    assert "foreground: #3C3C43;" in app.ROFI.read_text()


@pytest.mark.parametrize("args", [["glass", "maybe"], ["set", "size", "1"], ["set", "card", "x"], ["set", "text", "red"],
                                  ["tone", "pink"], ["what"]])
def test_bad_arguments_change_nothing(app, args):
    assert app.main(args) == 2
    assert not app.STATE.exists()


def test_a_broken_state_file_falls_back_to_the_first_tone(app):
    app.STATE.parent.mkdir(parents=True)
    app.STATE.write_text("not json")
    assert app.current(app.load_state(), app.palettes()) == "black"


def test_without_rofi_or_swaync_only_the_glass_is_written(app):
    app.ROFI.parent.rmdir()
    app.SWAYNC.parent.rmdir()
    app.main(["tone", "light"])
    assert app.GLASS.exists() and "swaync-client" not in app.calls()


def test_every_tone_has_every_colour():
    tones = json.loads(PALETTES.read_text())
    keys = {"label", "background", "foreground", "accent", "selection", "border", "card", "lift", "glass"}
    assert all(set(tone) - {"from"} == keys for tone in tones.values())
    assert all(set(t["glass"]) == {"blur", "brightness", "contrast", "saturation", "tint"} for t in tones.values())


def test_the_repo_starts_with_the_first_tones_colours(app):
    name, tone = app.resolve(app.palettes(), {})
    assert (DOTCONFIG / "rofi/hyprflow/colors.rasi").read_text() == app.rofi_colours(name, tone)
    assert (DOTCONFIG / "swaync/colors.css").read_text() == app.swaync_colours(name, tone)


def test_install_never_overwrites_the_chosen_colours():
    assert "rofi/hyprflow/colors.rasi swaync/colors.css" in (REPO / "install.sh").read_text()


def test_every_panel_gets_the_glass():
    qml = DOTCONFIG / "quickshell" / "hyprflow"
    panels = {m for f in qml.glob("*.qml") for m in re.findall(r'name: "(hyprflow-[\w-]+)"', f.read_text())}
    lua = (DOTCONFIG / "hypr" / "plugins.lua").read_text()
    assert "hyprflow-appearance" in panels and all(f'"{name}"' in lua for name in panels)


def test_the_glass_file_is_lua_hyprland_can_load(app, tmp_path):
    app.main(["tone", "light"])
    if not subprocess.run(["which", "luac"], capture_output=True).returncode:
        assert subprocess.run(["luac", "-p", str(app.GLASS)]).returncode == 0
