"""Shared fixtures. The scripts under bin/ are named for the command line
(battery-hub.py), which `import` cannot load, so they are loaded by path."""

import importlib.util
from pathlib import Path

import pytest

BIN = Path(__file__).resolve().parent.parent / "bin"


def load_script(filename):
    spec = importlib.util.spec_from_file_location(filename.replace("-", "_").removesuffix(".py"),
                                                  BIN / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="session")
def hub():
    return load_script("battery-hub.py")
