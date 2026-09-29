"""Tests for the shared pieces in lib/hyprflow/: paths, palette, hyprland and
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


def test_hyprland_query_dispatch_and_batch(fake):
    from hyprflow import hyprland
    assert hyprland.query("monitors", "all") == {"id": 1}
    hyprland.dispatch("hl.dsp.exit()")
    hyprland.batch("hl.dsp.focus({window='address:0x1'})", "hl.dsp.layout('swapwithmaster master')")
    assert fake() == [
        "hyprctl|monitors|all|-j|",
        "hyprctl|dispatch|hl.dsp.exit()|",
        "hyprctl|--batch|dispatch hl.dsp.focus({window='address:0x1'}) ; "
        "dispatch hl.dsp.layout('swapwithmaster master')|",
    ]


def fake_hyprctl(tmp_path, monkeypatch, body):
    (tmp_path / "bin").mkdir(exist_ok=True)
    (tmp_path / "bin" / "hyprctl").write_text(f"#!/bin/bash\n{body}\n")
    (tmp_path / "bin" / "hyprctl").chmod(0o755)
    monkeypatch.setenv("PATH", f"{tmp_path / 'bin'}:{os.environ['PATH']}")


@pytest.mark.parametrize("body, reason", [
    ('echo "HYPRLAND_INSTANCE_SIGNATURE not set" >&2; exit 1', "not set"),
    ("echo 'ok, not json'", "not JSON"),
    ("sleep 5", "no answer"),
])
def test_hyprland_query_failures_are_one_oserror(tmp_path, monkeypatch, body, reason):
    from hyprflow import hyprland
    monkeypatch.setattr(hyprland, "TIMEOUT", 0.5)
    fake_hyprctl(tmp_path, monkeypatch, body)
    with pytest.raises(hyprland.HyprlandError, match=reason) as caught:
        hyprland.query("monitors")
    assert isinstance(caught.value, OSError)   # what callers already catch


def test_hyprland_without_hyprctl_is_the_same_error(tmp_path, monkeypatch):
    from hyprflow import hyprland
    monkeypatch.setenv("PATH", str(tmp_path))   # no hyprctl anywhere
    with pytest.raises(hyprland.HyprlandError):
        hyprland.dispatch("hl.dsp.exit()")


def test_notify_passes_app_urgency_icon_and_body(fake):
    from hyprflow import notify
    notify.send("MX Keys Mini: 15%", "Running low.", app="Battery", urgency="critical", icon="battery-low")
    notify.send("Just a title")
    notify.send("-Weird Mouse: 10%")   # a device name is the hardware's, dash and all
    assert fake() == [
        "notify-send|-a|Battery|-u|critical|-i|battery-low|--|MX Keys Mini: 15%|Running low.|",
        "notify-send|-a|HyprFlow|-u|normal|--|Just a title|",
        "notify-send|-a|HyprFlow|-u|normal|--|-Weird Mouse: 10%|",
    ]


def test_hyprland_events_reads_the_socket_line_by_line(monkeypatch, tmp_path):
    import socket
    import threading
    from hyprflow import hyprland
    monkeypatch.setattr(hyprland.paths, "RUNTIME", tmp_path)   # the module hyprctl holds
    monkeypatch.setenv("HYPRLAND_INSTANCE_SIGNATURE", "sig")
    (tmp_path / "hypr" / "sig").mkdir(parents=True)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(tmp_path / "hypr" / "sig" / ".socket2.sock"))
    server.listen(1)

    def talk():
        conn, _ = server.accept()
        conn.sendall(b"monitoradded>>HDMI-A-1\nworkspace>>")      # the rest comes later
        conn.sendall(b"2\n")
        conn.close()

    threading.Thread(target=talk, daemon=True).start()
    assert list(hyprland.events()) == ["monitoradded>>HDMI-A-1", "workspace>>2"]
    server.close()


def test_hyprland_events_outside_hyprland(monkeypatch):
    from hyprflow import hyprland
    monkeypatch.delenv("HYPRLAND_INSTANCE_SIGNATURE", raising=False)
    with pytest.raises(OSError):
        next(hyprland.events())


def test_single_instance_lets_one_copy_run(tmp_path):
    import subprocess
    code = ("import sys, time; sys.path.insert(0, %r); from hyprflow.lock import single_instance; "
            "lock = single_instance('helper'); print('running', flush=True); time.sleep(5)") % str(LIB)
    env = {**os.environ, "XDG_RUNTIME_DIR": str(tmp_path)}
    first = subprocess.Popen([sys.executable, "-c", code], env=env, stdout=subprocess.PIPE, text=True)
    assert first.stdout.readline() == "running\n"
    second = subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, text=True, timeout=10)
    first.kill()
    first.wait()
    assert second.returncode == 0 and second.stdout == ""   # left quietly, never ran
    assert (tmp_path / "helper.lock").exists()


def rofi_answers(monkeypatch, code, out, seen=None):
    from hyprflow import menu

    def run(cmd, **kwargs):
        if seen is not None:
            seen.append(cmd)
        return type("R", (), {"returncode": code, "stdout": out})()
    monkeypatch.setattr(menu.subprocess, "run", run)
    return menu


def test_menu_choose_gives_the_row_index(monkeypatch):
    seen = []
    menu = rofi_answers(monkeypatch, 0, "2\n", seen)
    assert menu.RofiMenu(width=500).choose("Actions", ["a", "b", "c"]) == 2
    assert "window { width: 500px; }" in " ".join(seen[0])


def test_menu_choose_dismissed_is_none(monkeypatch):
    menu = rofi_answers(monkeypatch, 1, "")
    assert menu.RofiMenu().choose("Actions", ["a"]) is None


def test_menu_pick_tells_delete_from_enter(monkeypatch):
    menu = rofi_answers(monkeypatch, 10, "1")
    assert menu.RofiMenu().pick("Layout", ["a", "b"], "") == menu.Choice(1, delete=True)


def test_a_stuck_rofi_counts_as_dismissed(monkeypatch):
    import subprocess
    from hyprflow import menu

    def stuck(*a, **k):
        raise subprocess.TimeoutExpired(a[0], k.get("timeout"))
    monkeypatch.setattr(menu.subprocess, "run", stuck)
    assert menu.RofiMenu().choose("Load", ["a", "b"]) is None
