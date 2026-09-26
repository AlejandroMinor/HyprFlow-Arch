"""Tests for bin/game-mode.sh. The script runs for real, from a copy in a temp
folder next to fake monitors.sh and rgb-sync.sh (it looks for them beside
itself), with fake hyprctl, pactl, swaync-client, pgrep and pkill first on
PATH. Every fake logs its call, so nothing touches the screens, the sound,
the lights or Steam."""

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent

MONITORS = [
    {"name": "DP-1", "description": "NZXT Canvas 27Q", "width": 2560, "height": 1440, "disabled": False},
    {"name": "HDMI-A-1", "description": "AMZ FireTV", "width": 1920, "height": 1080, "disabled": False},
]
SINKS = [
    {"name": "alsa_output.usb-headset", "properties": {"node.nick": "G733"}},
    {"name": "alsa_output.hdmi-firetv", "properties": {"node.nick": "FireTV"}},
]

FAKES = {
    "hyprctl": """
        case "$1 ${2:-}" in
            "version "*)     [ -z "${FAKE_NO_HYPR:-}" ] ;;
            "instances "*)   cat "$T/instances.json" ;;
            "monitors "*)    cat "$T/monitors.json" ;;
            "clients "*)     cat "$T/clients.json" 2>/dev/null || echo '[]' ;;
        esac
    """,
    "pactl": """
        case "$*" in
            "-f json list sinks")  cat "$T/sinks.json" ;;
            "get-default-sink")    cat "$T/sink" ;;
            "set-default-sink "*)  echo "$2" > "$T/sink" ;;
        esac
    """,
    "swaync-client": '[ "$1" = -D ] && echo "${FAKE_DND:-false}"; exit 0',
    # FAKE_RUNNING lists the processes that "run": steam, waybar...
    "pgrep": '[[ " ${FAKE_RUNNING:-} " == *" ${@: -1} "* ]]',
    "pkill": "",
    "setsid": 'exec "$@"',
    "monitors.sh": 'exit "${FAKE_SOLO_FAIL:-0}"',
    "rgb-sync.sh": "",
    "waybar-restart.sh": "",   # lives in lib/, next to bin/
}


class GameMode:
    def __init__(self, root):
        self.root = root
        self.state = root / "state" / "hyprflow" / "game-mode"
        self.conf = root / "config" / "hypr" / "game-mode.conf"
        bindir = root / "bin"
        fakes = root / "fakebin"
        bindir.mkdir()
        fakes.mkdir()
        (root / "lib").mkdir()
        shutil.copy(REPO / "bin" / "game-mode.sh", bindir)
        for name, body in FAKES.items():
            where = {"waybar-restart.sh": root / "lib"}.get(
                name, bindir if name.endswith(".sh") else fakes)
            script = where / name
            script.write_text(f'#!/bin/bash\necho "{name} $*" >> "$T/log"\n{body}\n')
            script.chmod(0o755)
        (root / "log").write_text("")
        (root / "monitors.json").write_text(json.dumps(MONITORS))
        (root / "sinks.json").write_text(json.dumps(SINKS))
        (root / "sink").write_text("alsa_output.usb-headset\n")
        (root / "instances.json").write_text(json.dumps(
            [{"instance": "old_1", "time": 100}, {"instance": "new_2", "time": 200}]))
        self.conf.parent.mkdir(parents=True)
        self.config('GAME_DISPLAY=("FireTV" "NZXT")')
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND_"))}
        self.env.update(T=str(root), HOME=str(root), PATH=f"{fakes}:{os.environ['PATH']}",
                        XDG_CONFIG_HOME=str(root / "config"), XDG_STATE_HOME=str(root / "state"),
                        XDG_RUNTIME_DIR=str(root), HYPRLAND_INSTANCE_SIGNATURE="test")

    def config(self, *lines):
        self.conf.write_text("\n".join(lines) + "\n")

    def run(self, *args, **env):
        result = subprocess.run([str(self.root / "bin" / "game-mode.sh"), *args], text=True,
                                capture_output=True, env={**self.env, **env}, timeout=30)
        time.sleep(0.05)  # rgb-sync.sh runs detached
        return result

    def log(self):
        return (self.root / "log").read_text().splitlines()

    def called(self, prefix):
        return [line for line in self.log() if line.startswith(prefix)]

    def state_values(self):
        return dict(line.split("=", 1) for line in self.state.read_text().splitlines())

    def sink(self):
        return (self.root / "sink").read_text().strip()


@pytest.fixture
def gm(tmp_path):
    return GameMode(tmp_path)


# on

def test_on_uses_the_first_connected_screen_of_the_list(gm):
    result = gm.run("on")
    assert result.returncode == 0, result.stderr
    assert "monitors.sh solo on AMZ FireTV" in gm.log()
    assert "on: AMZ FireTV" in result.stdout


def test_on_skips_screens_that_are_not_connected(gm):
    gm.config('GAME_DISPLAY=("Samsung" "NZXT")')
    gm.run("on")
    assert "monitors.sh solo on NZXT Canvas 27Q" in gm.log()


def test_a_screen_on_the_command_line_beats_the_config(gm):
    gm.run("on", "DP-1")
    assert "monitors.sh solo on NZXT Canvas 27Q" in gm.log()


def test_without_a_list_the_largest_screen_wins(gm):
    gm.config('GAME_DISPLAY=""')
    gm.run("on")
    assert "monitors.sh solo on NZXT Canvas 27Q" in gm.log()


def test_on_fails_cleanly_when_no_screen_matches(gm):
    gm.config('GAME_DISPLAY=("Samsung")')
    result = gm.run("on")
    assert result.returncode == 1
    assert "none of these screens is connected" in result.stderr
    assert not gm.state.exists()


def test_on_writes_the_state_and_quiets_the_desktop(gm):
    gm.run("on")
    assert gm.state_values() == {"solo": "1", "dnd": "false", "vrr": "2", "steam_was": "0",
                                 "sink_prev": "alsa_output.usb-headset"}
    log = gm.log()
    assert "hyprctl reload" in log
    assert "swaync-client -dn" in log
    assert "pkill -x waybar" in log
    assert "rgb-sync.sh --off" in log
    assert any('focus({ monitor = \\"HDMI-A-1\\" })' in line or 'monitor = "HDMI-A-1"' in line
               for line in gm.called("hyprctl eval"))


def test_on_moves_the_sound_to_the_screen(gm):
    gm.run("on")
    assert gm.sink() == "alsa_output.hdmi-firetv"


def test_a_screen_without_speakers_leaves_the_sound(gm):
    gm.run("on", "NZXT")
    assert gm.sink() == "alsa_output.usb-headset"
    assert "sink_prev" not in gm.state_values()


def test_keep_leaves_the_other_screens_on(gm):
    result = gm.run("on", "--keep")
    assert not gm.called("monitors.sh")
    assert gm.state_values()["solo"] == "0"
    assert "other screens kept on" in result.stdout


def test_a_failed_switch_undoes_the_state(gm):
    result = gm.run("on", FAKE_SOLO_FAIL="1")
    assert result.returncode == 1
    assert not gm.state.exists()


def test_steam_starts_in_big_picture_when_closed(gm):
    gm.run("on")
    assert any("steam -gamepadui" in line for line in gm.called("hyprctl eval"))


def test_a_running_steam_is_switched_to_big_picture(gm):
    gm.run("on", FAKE_RUNNING="steam")
    assert any("steam://open/bigpicture" in line for line in gm.called("hyprctl eval"))
    assert gm.state_values()["steam_was"] == "1"


def test_settings_can_turn_parts_off(gm):
    gm.config('GAME_DISPLAY=("FireTV")', "GAME_STEAM=0", "GAME_RGB=0", "GAME_AUDIO=0", "GAME_VRR=0")
    gm.run("on")
    assert not any("steam" in line for line in gm.called("hyprctl eval"))
    assert not gm.called("rgb-sync.sh")
    assert gm.sink() == "alsa_output.usb-headset"
    assert gm.state_values()["vrr"] == "0"


def test_on_twice_does_nothing_the_second_time(gm):
    gm.run("on")
    (gm.root / "log").write_text("")
    result = gm.run("on")
    assert "already on" in result.stdout
    assert gm.log() == ["hyprctl version"]   # attaching to the session, nothing else


# off

def test_off_puts_everything_back(gm):
    gm.run("on")
    (gm.root / "log").write_text("")
    result = gm.run("off")
    assert result.returncode == 0
    assert not gm.state.exists()
    log = gm.log()
    assert "monitors.sh solo off" in log
    assert "hyprctl reload" in log
    assert "swaync-client -df" in log
    assert "rgb-sync.sh --last" in log
    assert gm.sink() == "alsa_output.usb-headset"
    assert "waybar-restart.sh " in log


def test_off_keeps_do_not_disturb_if_it_was_on_before(gm):
    gm.run("on", FAKE_DND="true")
    gm.run("off")
    assert "swaync-client -df" not in gm.log()


def test_off_closes_steam_if_game_mode_opened_it(gm):
    gm.run("on")
    gm.run("off", FAKE_RUNNING="steam")
    assert any("steam -shutdown" in line for line in gm.called("hyprctl eval"))


def test_off_only_leaves_big_picture_if_steam_was_open(gm):
    gm.run("on", FAKE_RUNNING="steam")
    gm.run("off", FAKE_RUNNING="steam")
    evals = gm.called("hyprctl eval")
    assert any("steam://close/bigpicture" in line for line in evals)
    assert not any("steam -shutdown" in line for line in evals)


def test_off_after_keep_leaves_the_monitors_alone(gm):
    gm.run("on", "--keep")
    gm.run("off")
    assert not gm.called("monitors.sh")


def test_off_when_already_off(gm):
    result = gm.run("off")
    assert "already off" in result.stdout
    assert not gm.called("monitors.sh")


# toggle, status, big picture, session

def test_toggle_and_status(gm):
    assert gm.run("status").stdout.strip() == "off"
    gm.run("toggle")
    assert gm.run("status").stdout.strip() == "on"
    gm.run("toggle")
    assert gm.run("status").stdout.strip() == "off"


def test_no_argument_means_toggle(gm):
    gm.run()
    assert gm.state.exists()


def test_closing_big_picture_ends_game_mode(gm):
    gm.run("on")
    gm.run("bigpicture-closed")
    assert not gm.state.exists()


def test_big_picture_reopening_by_itself_keeps_game_mode(gm):
    gm.run("on")
    (gm.root / "clients.json").write_text(json.dumps([{"title": "Steam Big Picture Mode"}]))
    gm.run("bigpicture-closed")
    assert gm.state.exists()


def test_over_ssh_it_finds_the_newest_running_session(gm):
    env = dict(gm.env)
    del env["HYPRLAND_INSTANCE_SIGNATURE"]
    gm.env = env
    (gm.root / "fakebin" / "hyprctl").write_text(
        (gm.root / "fakebin" / "hyprctl").read_text().replace(
            'echo "hyprctl $*"', 'echo "hyprctl[$HYPRLAND_INSTANCE_SIGNATURE] $*"'))
    gm.run("status")
    assert "hyprctl[new_2] version" in gm.log()


def test_without_a_running_session_it_says_so(gm):
    result = gm.run("on", FAKE_NO_HYPR="1")
    assert result.returncode == 1
    assert "no running Hyprland session found" in result.stderr
    assert not gm.state.exists()


def test_unknown_command(gm):
    result = gm.run("dance")
    assert result.returncode == 1
    assert "usage" in result.stderr
