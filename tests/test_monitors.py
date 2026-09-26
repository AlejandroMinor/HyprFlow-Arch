"""Tests for bin/monitors.sh. It runs from a copy in a temp folder with a fake
hyprctl that reports two monitors, a fake waybar-restart.sh next to it, and a
throwaway config dir, so no real screen is touched. The ports are made up
(TEST-A, TEST-B) so the /sys/class/drm connector check finds nothing and
treats them as connected."""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent

BIG = {"name": "TEST-A", "description": "NZXT Canvas 27Q", "width": 2560, "height": 1440,
       "refreshRate": 164.998, "scale": 1.0, "disabled": False,
       "availableModes": ["2560x1440@165.00Hz", "2560x1440@60.00Hz", "1920x1080@60.00Hz"]}
SMALL = {"name": "TEST-B", "description": "AOC 24B3HM", "width": 1920, "height": 1080,
         "refreshRate": 74.97, "scale": 1.0, "disabled": False,
         "availableModes": ["1920x1080@75.00Hz", "1920x1080@60.00Hz"]}
SIG = "AOC 24B3HM|NZXT Canvas 27Q"

HYPRCTL = """
case "$1" in
    monitors)       cat "$T/monitors.json" ;;
    workspaces)     echo '[]' ;;
    activeworkspace) echo '{"id": 1}' ;;
esac
"""


class Monitors:
    def __init__(self, root):
        self.root = root
        self.config = root / "config"
        (root / "bin").mkdir()
        (root / "lib").mkdir()
        (root / "fakebin").mkdir()
        shutil.copy(REPO / "bin" / "monitors.sh", root / "bin")
        (self.config / "waybar").mkdir(parents=True)
        shutil.copy(REPO / "dotconfig" / "waybar" / "bars.json", self.config / "waybar")
        self.fake(root / "fakebin" / "hyprctl", HYPRCTL)
        self.fake(root / "fakebin" / "pgrep", '[[ " ${FAKE_RUNNING:-} " == *" ${@: -1} "* ]]')
        self.fake(root / "fakebin" / "notify-send", "")
        self.fake(root / "fakebin" / "awww", "")        # the real one would repaint the wallpaper
        self.fake(root / "lib" / "waybar-restart.sh", "")
        (root / "log").write_text("")
        self.connect(BIG, SMALL)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND_"))}
        self.env.update(T=str(root), HOME=str(root), XDG_CONFIG_HOME=str(self.config),
                        XDG_STATE_HOME=str(root / "state"), PATH=f"{root / 'fakebin'}:{os.environ['PATH']}")

    @staticmethod
    def fake(path, body):
        path.write_text(f'#!/bin/bash\necho "{path.name} $*" >> "$T/log"\n{body}\n')
        path.chmod(0o755)

    def connect(self, *monitors):
        (self.root / "monitors.json").write_text(json.dumps(list(monitors)))

    def run(self, *args, **env):
        (self.root / "log").write_text("")
        return subprocess.run([str(self.root / "bin" / "monitors.sh"), *args], text=True,
                              capture_output=True, env={**self.env, **env}, timeout=60)

    def log(self):
        return (self.root / "log").read_text().splitlines()

    @property
    def lua(self):
        return (self.config / "hypr" / "monitors_active.lua").read_text()

    @property
    def bars(self):
        return json.loads((self.config / "waybar" / "config").read_text())

    def save_profile(self, entries, sig=SIG):
        (self.config / "hypr").mkdir(parents=True, exist_ok=True)
        (self.config / "hypr" / "monitor-profiles.json").write_text(json.dumps({sig: entries}))


@pytest.fixture
def mon(tmp_path):
    return Monitors(tmp_path)


def entry(monitor, **extra):
    return {"description": monitor["description"], "mode": "%dx%d@60" % (monitor["width"], monitor["height"]),
            "scale": 1.0, "transform": 0, "primary": False, "bar": "minimal", **extra}


# apply

def test_without_a_profile_the_largest_screen_is_primary(mon):
    result = mon.run("apply")
    assert result.returncode == 0, result.stderr
    assert 'hl.monitor({ output = "TEST-A", mode = "2560x1440@165.00", position = "0x0", scale = 1.0, transform = 0 })' in mon.lua
    assert 'hl.monitor({ output = "TEST-B", mode = "1920x1080@75.00", position = "2560x0", scale = 1.0, transform = 0 })' in mon.lua
    assert 'hl.workspace_rule({ workspace = "1", monitor = "TEST-A" })' in mon.lua
    assert 'hl.workspace_rule({ workspace = "3", monitor = "TEST-B" })' in mon.lua
    assert "notify-send -a Monitors Monitors Using default layout. Run 'monitors.sh setup' to customize." in mon.log()


def test_each_screen_gets_the_bar_its_profile_names(mon):
    mon.run("apply")
    by_output = {bar["output"][0]: bar for bar in mon.bars}
    assert "modules-right" in by_output["TEST-A"]            # full bar
    assert by_output["TEST-A"]["width"] == 2560 - 120
    assert by_output["TEST-B"]["name"] == "minimal"


def test_apply_reloads_and_restarts_waybar_only_on_change(mon):
    mon.run("apply")
    assert "hyprctl reload" in mon.log()
    assert "waybar-restart.sh " in mon.log()
    result = mon.run("apply", FAKE_RUNNING="waybar")
    assert "no changes" in result.stdout
    assert "hyprctl reload" not in mon.log()
    assert "waybar-restart.sh " not in mon.log()


def test_a_saved_profile_wins_and_portrait_screens_rotate_the_layout(mon):
    mon.save_profile([entry(BIG, primary=True, bar="full"),
                      entry(SMALL, transform=3, scale=1.5)])
    mon.run("apply")
    assert 'hl.monitor({ output = "TEST-B", mode = "1920x1080@60", position = "2560x0", scale = 1.5, transform = 3 })' in mon.lua
    # Portrait: the next screen would start at 1080 / 1.5 = 720 logical pixels.
    assert 'layout_opts = { orientation = "top" }' in mon.lua


def test_a_disabled_screen_is_switched_off_and_gets_no_bar(mon):
    mon.save_profile([entry(BIG, primary=True, bar="full"), entry(SMALL, disabled=True)])
    mon.run("apply")
    assert 'hl.monitor({ output = "TEST-B", disabled = true })' in mon.lua
    assert [bar["output"] for bar in mon.bars] == [["TEST-A"]]


def test_game_mode_keeps_waybar_hidden(mon):
    state = mon.root / "state" / "hyprflow"
    state.mkdir(parents=True)
    (state / "game-mode").write_text("solo=1\n")
    result = mon.run("apply")
    assert "leaving Waybar hidden" in result.stdout
    assert "waybar-restart.sh " not in mon.log()


# solo

def test_solo_keeps_one_screen_and_switches_the_rest_off(mon):
    mon.run("apply")
    result = mon.run("solo", "on", "TEST-B")
    assert result.returncode == 0, result.stderr
    assert 'hl.monitor({ output = "TEST-A", disabled = true })' in mon.lua
    assert 'hl.workspace_rule({ workspace = "1", monitor = "TEST-B" })' in mon.lua
    assert (mon.config / "hypr" / "monitor-solo.json").exists()


def test_solo_survives_an_apply_and_ends_with_solo_off(mon):
    mon.run("apply")
    mon.run("solo", "on", "AOC 24B3HM")
    mon.run("apply")                                          # a hotplug, say
    assert 'output = "TEST-A", disabled = true' in mon.lua
    mon.run("solo", "off")
    assert not (mon.config / "hypr" / "monitor-solo.json").exists()
    assert 'output = "TEST-A", mode' in mon.lua


def test_solo_in_a_mode_the_screen_does_not_offer_is_refused(mon):
    result = mon.run("solo", "on", "TEST-B", "3840x2160@60")
    assert result.returncode == 1
    assert "does not offer 3840x2160@60" in result.stderr
    assert not (mon.config / "hypr" / "monitor-solo.json").exists()


def test_solo_in_another_offered_mode(mon):
    mon.run("solo", "on", "TEST-A", "1920x1080@60")
    assert 'output = "TEST-A", mode = "1920x1080@60"' in mon.lua


def test_solo_on_an_unknown_screen(mon):
    result = mon.run("solo", "on", "HDMI-Z-9")
    assert result.returncode == 1
    assert "unknown monitor: HDMI-Z-9" in result.stderr


# mirror

def test_mirror_clones_the_primary_at_a_common_resolution_and_off_restores(mon):
    mon.run("apply")
    mon.run("mirror", "on")
    assert 'output = "TEST-B", mode = "1920x1080@75", position = "auto", scale = 1.0, mirror = "TEST-A"' in mon.lua
    assert 'output = "TEST-A", mode = "1920x1080@60"' in mon.lua
    mon.run("mirror", "off")
    assert "mirror" not in mon.lua.split("\n\n", 1)[1]
    assert 'position = "2560x0"' in mon.lua


def test_mirror_needs_two_screens(mon):
    mon.connect(BIG)
    result = mon.run("mirror", "on")
    assert result.returncode == 1
    assert "at least 2 monitors" in result.stderr


# list, usage

def test_list_shows_the_current_mode_or_off(mon):
    mon.connect(BIG, {**SMALL, "disabled": True})
    out = mon.run("list").stdout
    assert "NZXT Canvas 27Q" in out and "2560x1440@165Hz" in out
    assert out.splitlines()[2].split()[-2] == "off"


def test_unknown_command(mon):
    result = mon.run("dance")
    assert result.returncode == 1
    assert "usage" in result.stderr
