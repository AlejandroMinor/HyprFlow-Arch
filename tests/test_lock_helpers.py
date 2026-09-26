"""Tests for the lockscreen helpers in dotconfig/hypr/hyprlock/: the battery
label, the now playing block (with its privacy rule) and the avatar. Players,
batteries and desktop entries are fakes in a throwaway $HOME."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

LOCK = Path(__file__).resolve().parent.parent / "dotconfig" / "hypr" / "hyprlock"


def sh(script, *args, env):
    return subprocess.run(["bash", str(LOCK / script), *args], env=env, text=True,
                          capture_output=True, timeout=30).stdout.strip()


# battery.sh

@pytest.fixture
def battery(tmp_path):
    bat = tmp_path / "BAT0"
    bat.mkdir()
    env = {**os.environ, "POWER_SUPPLY": str(tmp_path)}

    def read(capacity, status="Discharging"):
        (bat / "capacity").write_text(f"{capacity}\n")
        (bat / "status").write_text(f"{status}\n")
        return sh("battery.sh", env=env)

    return read, env, bat


@pytest.mark.parametrize("capacity, icon", [(95, "󰁹"), (75, "󰂀"), (55, "󰁾"), (35, "󰁼"), (20, "󰁺"), (5, "󰂃")])
def test_battery_icon_follows_the_charge(battery, capacity, icon):
    read, _, _ = battery
    assert read(capacity) == f"{icon} {capacity}%"


def test_battery_charging_icon(battery):
    read, _, _ = battery
    assert read(40, "Charging") == "󰂄 40%"


def test_no_battery_prints_nothing(battery, tmp_path):
    _, env, bat = battery
    shutil.rmtree(bat)
    assert sh("battery.sh", env=env) == ""


def test_garbage_capacity_prints_nothing(battery):
    read, _, _ = battery
    assert read("n/a") == ""


# music.sh

PLAYERCTL = r'''
case "$*" in
    *"metadata --format {{playerName}}"*) echo "$FAKE_PLAYER" ;;
    *"metadata --format {{title}}"*)      echo "Constitución" ;;
    *"metadata --format {{artist}}"*)     echo "Las eras" ;;
    *"status"*)                           echo "Playing" ;;
esac
'''


@pytest.fixture
def music(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in {"playerctl": PLAYERCTL, "busctl": "exit 1"}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    apps = tmp_path / ".local" / "share" / "applications"
    apps.mkdir(parents=True)
    (apps / "spotify.desktop").write_text("[Desktop Entry]\nName=Spotify\nCategories=Audio;Music;Player;AudioVideo;\n")
    (apps / "firefox.desktop").write_text("[Desktop Entry]\nName=Firefox\nCategories=Network;WebBrowser;\n")
    env = {**os.environ, "HOME": str(tmp_path), "XDG_CACHE_HOME": str(tmp_path / "cache"),
           "PATH": f"{fakes}:{os.environ['PATH']}"}
    return lambda player, *args: sh("music.sh", *args, env={**env, "FAKE_PLAYER": player})


def test_a_music_app_shows_the_track(music):
    assert music("spotify", "--title") == "Constitución"
    assert music("spotify", "--subtitle") == "󰐊  Las eras"


def test_a_browser_shows_only_its_name_never_the_tab(music):
    assert music("firefox", "--title") == "Firefox"
    assert music("firefox", "--subtitle") == "󰐊  Playing"


def test_an_unknown_player_is_treated_as_private(music):
    assert music("mystery", "--title") == "Mystery"


def test_nothing_playing_prints_nothing_but_art_still_gets_a_path(music):
    assert music("", "--title") == ""
    art = music("", "--art-now")
    assert art.endswith("lockart-none.png")


# avatar.sh

@pytest.fixture
def avatar(tmp_path):
    env = {**os.environ, "XDG_CONFIG_HOME": str(tmp_path)}
    return tmp_path / "hypr" / "avatar.png", lambda *a: sh("avatar.sh", *a, env=env)


def test_an_existing_avatar_is_never_touched(avatar):
    path, run = avatar
    path.parent.mkdir(parents=True)
    path.write_bytes(b"my face")
    run()
    assert path.read_bytes() == b"my face"


@pytest.mark.skipif(not shutil.which("magick"), reason="needs ImageMagick")
def test_a_missing_avatar_gets_the_arch_glyph(avatar):
    path, run = avatar
    run()
    assert path.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
