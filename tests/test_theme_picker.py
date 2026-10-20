"""Tests for bin/theme-picker.sh and wallust-theme-manager.sh --theme. Both
run from copies in a temp folder, next to fakes of the scripts they call,
with fake fzf, wallust, hyprctl... first on PATH."""

import json
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
    # Answers $FAKE_QS_RC, so a test can say whether the panel is up.
    "qs": 'exit "${FAKE_QS_RC:-0}"',
}


@pytest.fixture
def box(tmp_path):
    (tmp_path / "bin").mkdir()
    (tmp_path / "lib").mkdir()
    (tmp_path / "fakebin").mkdir()
    for script in ("theme-picker.sh", "wallust-theme-manager.sh"):
        shutil.copy(REPO / "bin" / script, tmp_path / "bin")
    shutil.copy(REPO / "lib" / "fzf-colors.sh", tmp_path / "lib")
    shutil.copy(REPO / "lib" / "common.sh", tmp_path / "lib")

    def fake(path, body):
        path.write_text(f'#!/bin/bash\necho "{path.name} $*" >> "$T/log"\n{body}\n')
        path.chmod(0o755)

    for name, body in FAKES.items():
        fake(tmp_path / "fakebin" / name, body)
    fake(tmp_path / "lib" / "bar-restart.sh", "")
    fake(tmp_path / "bin" / "rgb-sync.sh", "")
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


def run(box, *args, **extra):
    root, env = box
    result = subprocess.run([str(root / "bin" / "theme-picker.sh"), *args],
                            env={**env, **extra}, text=True, capture_output=True, timeout=30)
    return result, (root / "log").read_text().splitlines()


def test_the_list_is_built_from_the_theme_files(box):
    pick(box, "")
    offered = (box[0] / "offered").read_text().splitlines()
    assert offered[:3] == ["Wallpaper (Auto)", "Classic", "Nocturne"]
    assert len(offered) == 1 + len(list(THEMES.glob("*.json")))
    assert "Accent Blue" in offered and "Tokyo Night" in offered
    accents = [t for t in offered if t.startswith("Accent ")]
    assert offered[3:3 + len(accents)] == sorted(accents)   # the accents next
    rest = offered[3 + len(accents):]
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
    assert "bar-restart.sh " in log


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
    assert "bar-restart.sh " not in log


def test_the_manager_fails_on_an_unknown_argument(box):
    result, log = pick(box, "", "wallust-theme-manager.sh", "--bogus")
    assert result.returncode == 1
    assert "Unknown argument: --bogus" in result.stderr and "Usage" in result.stderr
    assert not any(line.startswith("wallust") for line in log)


def test_the_manager_help_still_exits_cleanly(box):
    result, _ = pick(box, "", "wallust-theme-manager.sh", "--help")
    assert result.returncode == 0 and "Usage" in result.stdout


def test_the_manager_calls_rgb_sync_by_its_path_not_the_path_variable(box):
    _, log = pick(box, "", "wallust-theme-manager.sh", "--restore-default", "--no-restart")
    assert f"setsid {box[0]}/bin/rgb-sync.sh --last" in log


def test_the_accent_is_picked_before_the_reload_and_the_leds_follow(box):
    _, log = pick(box, "", "wallust-theme-manager.sh", "--restore-default", "--no-restart")
    assert log.index("rgb-sync.sh --pick") < log.index("hyprctl reload")
    assert f"setsid {box[0]}/bin/rgb-sync.sh --last" in log


def test_without_theme_files_the_list_has_no_stray_star(box):
    root, _ = box
    for theme in (root / "config" / "wallust" / "themes").glob("*.json"):
        theme.unlink()
    pick(box, "")
    offered = (root / "offered").read_text().splitlines()
    assert "*" not in offered


def test_json_is_the_list_the_panel_draws(box):
    result, _ = run(box, "--json")
    data = json.loads(result.stdout)
    assert (data[0]["name"], data[0]["title"]) == ("auto", "Wallpaper (Auto)")
    titles = [theme["title"] for theme in data]
    assert titles[1:3] == ["Classic", "Nocturne"]
    assert "Accent Blue" in titles
    assert len(data) == 1 + len(list(THEMES.glob("*.json")))


def test_json_gives_each_theme_its_section_and_colours(box):
    result, _ = run(box, "--json")
    data = {theme["name"]: theme for theme in json.loads(result.stdout)}
    assert [data[n]["section"] for n in ("auto", "classic", "accent-blue", "nord")] == \
        ["Wallpaper", "Base", "Accent", "Palettes"]
    palette = json.loads((THEMES / "nocturne.json").read_text())
    assert data["nocturne"]["colors"] == [
        palette["special"]["background"], palette["colors"]["color1"], palette["colors"]["color2"],
        palette["colors"]["color4"], palette["colors"]["color5"], palette["special"]["foreground"]]
    assert data["auto"]["colors"] == []   # not in use: nothing to show
    assert not any(theme["current"] for theme in data.values())


def test_the_theme_in_use_is_marked(box):
    run(box, "--set", "nord")
    result, _ = run(box, "--json")
    assert [t["name"] for t in json.loads(result.stdout) if t["current"]] == ["nord"]


def test_the_wallpaper_in_use_shows_the_current_palette(box):
    root, _ = box
    state = root / ".local" / "state" / "hyprflow"
    state.mkdir(parents=True)
    (state / "theme").write_text("auto\n")
    result, _ = run(box, "--json")
    auto = json.loads(result.stdout)[0]
    assert auto["current"] is True
    assert auto["colors"] == ["#123456", "#ffffff"]   # what the box palette has


def test_a_failed_theme_leaves_the_mark_alone(box):
    run(box, "--set", "nope")
    assert not (box[0] / ".local" / "state" / "hyprflow" / "theme").exists()


def test_set_applies_the_theme_without_a_menu(box):
    _, log = run(box, "--set", "accent-blue")
    themes = box[0] / ".config" / "wallust" / "themes"
    assert f"wallust cs {themes}/accent-blue.json" in log
    assert not any(line.startswith("fzf") for line in log)


def test_set_auto_generates_the_palette(box):
    _, log = run(box, "--set", "auto")
    assert not any(line.startswith("wallust cs") for line in log)
    assert any(line.startswith("hyprctl monitors") for line in log)


def test_toggle_opens_the_panel_when_quickshell_is_up(box):
    _, log = run(box, "--toggle", FAKE_QS_RC="0")
    assert any(line.startswith("qs -c hyprflow ipc call themepicker toggle") for line in log)
    assert not any("kitty-theme-picker" in line for line in log)


def test_toggle_falls_back_to_the_terminal_picker(box):
    _, log = run(box, "--toggle", FAKE_QS_RC="1")
    assert any("kitty-theme-picker" in line for line in log)
    assert not any(line.startswith("fzf") for line in log)  # kitty runs it, not us


def test_set_without_a_name_does_nothing(box):
    result, log = run(box, "--set")
    assert result.returncode == 1
    assert not any(line.startswith(("wallust", "hyprctl")) for line in log)


def test_json_escapes_quotes_in_a_file_name(box):
    root, _ = box
    (root / "config" / "wallust" / "themes" / 'odd"name.json').write_text("{}")
    result, _ = run(box, "--json")
    assert ('odd"name', 'Odd"name') in [(t["name"], t["title"]) for t in json.loads(result.stdout)]


def test_the_manager_says_which_theme_is_on(box):
    _, log = pick(box, "", "wallust-theme-manager.sh", "--theme", "accent-blue", "--notify", "--no-restart")
    assert any(line.startswith("qs -c hyprflow ipc call osd level") and "Theme Accent Blue -1" in line
               for line in log)
    assert not any(line.startswith("notify-send") for line in log)


def test_without_quickshell_the_manager_notifies_the_theme(box):
    root, env = box
    env["FAKE_QS_RC"] = "1"
    _, log = pick(box, "", "wallust-theme-manager.sh", "--theme", "nord", "--notify", "--no-restart")
    assert "notify-send -i color-management Theme Nord" in log
