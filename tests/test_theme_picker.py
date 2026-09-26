"""Tests for bin/theme-picker.sh and wallust-theme-manager.sh --theme. Both
run from copies in a temp folder, next to fakes of the scripts they call,
with fake fzf, wallust, hyprctl... first on PATH."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
THEMES = REPO / "dotconfig" / "wallust" / "themes"

FAKES = {
    # Logs its arguments and the list it was offered, answers $FAKE_PICK.
    "fzf": 'cat > "$T/offered"; printf "%s\\n" "${FAKE_PICK:-}"',
    "wallust": "",
    "hyprctl": "",
    "notify-send": "",
    "setsid": "",
    "killall": "",
}


@pytest.fixture
def box(tmp_path):
    (tmp_path / "bin").mkdir()
    (tmp_path / "lib").mkdir()
    (tmp_path / "fakebin").mkdir()
    for script in ("theme-picker.sh", "wallust-theme-manager.sh"):
        shutil.copy(REPO / "bin" / script, tmp_path / "bin")
    shutil.copy(REPO / "lib" / "fzf-colors.sh", tmp_path / "lib")

    def fake(path, body):
        path.write_text(f'#!/bin/bash\necho "{path.name} $*" >> "$T/log"\n{body}\n')
        path.chmod(0o755)

    for name, body in FAKES.items():
        fake(tmp_path / "fakebin" / name, body)
    fake(tmp_path / "lib" / "waybar-restart.sh", "")
    themes = tmp_path / "config" / "wallust" / "themes"
    shutil.copytree(THEMES, themes)
    palette = tmp_path / "palette.sh"
    palette.write_text("foreground='#ffffff'\ncolor4='#123456'\n")
    (tmp_path / "log").write_text("")
    env = {k: v for k, v in os.environ.items() if not k.startswith("XDG_")}
    env.update(T=str(tmp_path), HOME=str(tmp_path), XDG_CONFIG_HOME=str(tmp_path / "config"),
               PATH=f"{tmp_path / 'fakebin'}:{os.environ['PATH']}", WALLUST_SH_PALETTE=str(palette))
    # The manager reads $HOME/.config; point it at the same themes.
    (tmp_path / ".config").symlink_to(tmp_path / "config")
    return tmp_path, env


def pick(box, choice, script="theme-picker.sh", *args):
    root, env = box
    result = subprocess.run([str(root / "bin" / script), *args], env={**env, "FAKE_PICK": choice},
                            text=True, capture_output=True, timeout=30)
    return result, (root / "log").read_text().splitlines()


def test_the_list_is_built_from_the_theme_files(box):
    pick(box, "")
    offered = (box[0] / "offered").read_text().splitlines()
    assert offered[:3] == ["Wallpaper (Auto)", "Classic", "Nocturne"]
    assert len(offered) == 1 + len(list(THEMES.glob("*.json")))
    assert "Accent Blue" in offered and "Tokyo Night" in offered
    rest = offered[3:]
    assert rest == sorted(rest)


def test_a_new_theme_file_shows_up_by_itself(box):
    (box[0] / "config" / "wallust" / "themes" / "rose-pine.json").write_text("{}")
    pick(box, "")
    assert "Rose Pine" in (box[0] / "offered").read_text().splitlines()


def test_a_theme_goes_through_the_manager(box):
    _, log = pick(box, "Accent Blue")
    themes = box[0] / ".config" / "wallust" / "themes"
    assert f"wallust cs {themes}/accent-blue.json" in log
    assert "hyprctl reload" in log
    assert "waybar-restart.sh " in log


def test_the_wallpaper_entry_generates_a_palette(box):
    result, log = pick(box, "Wallpaper (Auto)")
    # No wallpaper to read in the box: it stops before wallust, but it asked.
    assert not any(line.startswith("wallust cs") for line in log)
    assert any(line.startswith("hyprctl monitors") for line in log)


def test_cancelling_changes_nothing(box):
    _, log = pick(box, "")
    assert [line for line in log if not line.startswith("fzf")] == []


def test_the_picker_follows_the_wallust_palette(box):
    _, log = pick(box, "")
    assert any("--color=bg:-1,fg:#ffffff" in line and "hl:#123456" in line for line in log)


def test_the_manager_refuses_an_unknown_theme(box):
    result, log = pick(box, "", "wallust-theme-manager.sh", "--theme", "nope")
    assert result.returncode == 1
    assert "no theme 'nope'" in result.stderr
    assert not any(line.startswith("wallust") for line in log)


def test_restore_default_is_classic(box):
    _, log = pick(box, "", "wallust-theme-manager.sh", "--restore-default", "--no-restart")
    assert f"wallust cs {box[0]}/.config/wallust/themes/classic.json" in log
    assert "waybar-restart.sh " not in log
