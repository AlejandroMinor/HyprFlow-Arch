"""Shared fixtures. Some scripts under lib/ are named for the command line
(battery-hub.py), which `import` cannot load, so they are loaded by path."""

import importlib.util
from pathlib import Path

import pytest

LIB = Path(__file__).resolve().parent.parent / "lib"


def load_script(filename):
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_").removesuffix(".py"),
                                                  LIB / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


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
def pad():
    return load_script("pad-listener.py")


@pytest.fixture(scope="session")
def waybar_module():
    spec = importlib.util.spec_from_file_location(
        "waybar_module", LIB / "waybar_module.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
