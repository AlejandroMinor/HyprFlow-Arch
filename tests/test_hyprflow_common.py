"""Tests for the shared pieces in lib/hyprflow/: paths, palette, hyprctl and
notify. The commands are fakes on PATH that log how they were called."""

import importlib
import os
import sys
from pathlib import Path

import pytest

LIB = Path(__file__).resolve().parent.parent / "lib"
sys.path.insert(0, str(LIB))


def fresh(name, monkeypatch, **env):
    """Import hyprflow.<name> again, with the given environment."""
    for key, value in env.items():
        monkeypatch.setenv(key, value)
    for module in ("hyprflow.paths", f"hyprflow.{name}"):
        sys.modules.pop(module, None)
    return importlib.import_module(f"hyprflow.{name}")


@pytest.fixture
def fake(tmp_path, monkeypatch):
    """Fake commands that log their arguments; returns a reader of the log."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    log = tmp_path / "log"
    for name, answer in {"hyprctl": 'echo \'{"id": 1}\'', "notify-send": ""}.items():
        (bin_dir / name).write_text(f'#!/bin/bash\nprintf "%s|" "{name}" "$@" >> "{log}"\necho >> "{log}"\n{answer}\n')
        (bin_dir / name).chmod(0o755)
    monkeypatch.setenv("PATH", f"{bin_dir}:{os.environ['PATH']}")
    return lambda: log.read_text().splitlines()


def test_paths_follow_the_xdg_variables(monkeypatch, tmp_path):
    paths = fresh("paths", monkeypatch, XDG_CONFIG_HOME=str(tmp_path / "c"),
                  XDG_STATE_HOME=str(tmp_path / "s"), XDG_RUNTIME_DIR=str(tmp_path / "r"))
    assert paths.HYPRFLOW_CONFIG == tmp_path / "c" / "hyprflow"
    assert paths.HYPRFLOW_STATE == tmp_path / "s" / "hyprflow"
    assert paths.HYPRFLOW_RUNTIME == tmp_path / "r"


def test_paths_default_under_home(monkeypatch):
    for variable in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
        monkeypatch.delenv(variable, raising=False)
    paths = fresh("paths", monkeypatch)
    assert paths.CONFIG == Path.home() / ".config"
    assert paths.STATE == Path.home() / ".local/state"


def test_palette_reads_wallusts_shell_file(tmp_path):
    from hyprflow import palette
    file = tmp_path / "colors-rofi-sh.conf"
    file.write_text("background='#050300'\ncolor5='#778D01'\n")
    assert palette.load(file) == {"background": "#050300", "color5": "#778D01"}
    assert palette.load(tmp_path / "missing") == {}


def test_hyprctl_query_dispatch_and_batch(fake):
    from hyprflow import hyprctl
    assert hyprctl.query("monitors", "all") == {"id": 1}
    hyprctl.dispatch("hl.dsp.exit()")
    hyprctl.batch("hl.dsp.focus({window='address:0x1'})", "hl.dsp.layout('swapwithmaster master')")
    assert fake() == [
        "hyprctl|monitors|all|-j|",
        "hyprctl|dispatch|hl.dsp.exit()|",
        "hyprctl|--batch|dispatch hl.dsp.focus({window='address:0x1'}) ; "
        "dispatch hl.dsp.layout('swapwithmaster master')|",
    ]


def test_notify_passes_app_urgency_icon_and_body(fake):
    from hyprflow import notify
    notify.send("MX Keys Mini: 15%", "Running low.", app="Battery", urgency="critical", icon="battery-low")
    notify.send("Just a title")
    assert fake() == [
        "notify-send|-a|Battery|-u|critical|-i|battery-low|MX Keys Mini: 15%|Running low.|",
        "notify-send|-a|HyprFlow|-u|normal|Just a title|",
    ]
