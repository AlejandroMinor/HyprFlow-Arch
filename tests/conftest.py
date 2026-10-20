"""Shared fixtures. Some scripts under lib/ are named for the command line
(battery-hub.py), which `import` cannot load, so they are loaded by path."""

import importlib
import importlib.util
import sys
from pathlib import Path

import pytest

LIB = Path(__file__).resolve().parent.parent / "lib"


def load_script(filename):
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_").removesuffix(".py"),
                                                  LIB / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(autouse=True)
def no_real_keyboard(monkeypatch):
    """rgb-sync.sh paints the real keyboard unless KEYBOARD_RGB says otherwise:
    every test, and every script it starts, gets a no-op instead."""
    monkeypatch.setenv("KEYBOARD_RGB", "/usr/bin/true")


@pytest.fixture(scope="session")
def hub():
    return load_script("battery-hub.py")


@pytest.fixture(scope="session")
def camera():
    return load_script("camera_status.py")


@pytest.fixture(scope="session")
def mute():
    return load_script("mute_indicator.py")


@pytest.fixture(scope="session")
def vpn():
    return load_script("vpn_status.py")


@pytest.fixture(scope="session")
def cava():
    return load_script("cava_waybar.py")


@pytest.fixture(scope="session")
def session():
    return load_script("session-manager.py")


@pytest.fixture(scope="session")
def help_binds():
    return load_script("help-binds-parse.py")


@pytest.fixture(scope="session")
def pick():
    return load_script("master-pick.py")


@pytest.fixture(scope="session")
def mons():
    return load_script("monitors.py")


@pytest.fixture(scope="session")
def pad():
    return load_script("pad-listener.py")


@pytest.fixture(scope="session")
def headset_watch():
    return load_script("headset-watch.py")


@pytest.fixture(scope="session")
def mic_mute_watch():
    return load_script("mic-mute-watch.py")


@pytest.fixture(scope="session")
def rgb_hotplug():
    return load_script("rgb-hotplug.py")


@pytest.fixture(scope="session")
def osd_watch():
    return load_script("osd-watch.py")


@pytest.fixture(scope="session")
def waybar_module():
    sys.path.insert(0, str(LIB))
    return importlib.import_module("hyprflow.waybar")
