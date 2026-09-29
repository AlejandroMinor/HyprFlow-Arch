"""Tests for lib/waybar-restart.sh with fake killall, hyprctl and setsid."""

import os
import subprocess
import time
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "waybar-restart.sh"

# $T/running holds one line per live Waybar. Hyprland starts one a moment after
# the dispatch, as the real one does; killall -w removes them all.
FAKES = {
    "killall": ': > "$T/running"',
    # FAKE_NO_HYPR: no compositor answers, as on a TTY.
    "hyprctl": '[ -n "${FAKE_NO_HYPR:-}" ] && exit 1; (sleep 0.3; echo w >> "$T/running") & echo ok',
    "setsid": 'echo "setsid GTK_PATH=${GTK_PATH:-unset} $*" >> "$FAKE_LOG"; exec "$@"',
    "waybar": 'echo w >> "$T/running"',
    "pgrep": '[ -s "$T/running" ]',
}


@pytest.fixture
def env(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in FAKES.items():
        (fakes / name).write_text(f'#!/bin/bash\necho "{name} $*" >> "$FAKE_LOG"\n{body}\n')
        (fakes / name).chmod(0o755)
    log = tmp_path / "log"
    log.write_text("")
    (tmp_path / "running").write_text("")
    return {**os.environ, "PATH": f"{fakes}:{os.environ['PATH']}", "FAKE_LOG": str(log),
            "GTK_PATH": "/snap/gtk", "T": str(tmp_path), "XDG_RUNTIME_DIR": str(tmp_path)}


def run(env, **extra):
    subprocess.run(["bash", str(SCRIPT)], env={**env, **extra}, check=True, timeout=10)
    time.sleep(0.1)   # the fallback starts Waybar in the background
    return Path(env["FAKE_LOG"]).read_text().splitlines()


def test_the_old_waybar_is_gone_before_hyprland_starts_the_new_one(env):
    log = run(env)
    assert log[0] == "killall -w waybar"
    assert log[1] == 'hyprctl dispatch hl.dsp.exec_cmd("waybar")'
    assert log[2] == "pgrep -x waybar"        # waits for the new one before leaving
    assert not any(line.startswith("setsid") for line in log)


def test_without_hyprland_it_starts_waybar_itself_without_the_sandbox_env(env):
    log = run(env, FAKE_NO_HYPR="1")
    assert "setsid GTK_PATH=unset waybar" in log
    assert "waybar " in log


def test_two_restarts_at_once_leave_one_waybar(env):
    both = [subprocess.Popen(["bash", str(SCRIPT)], env=env) for _ in range(2)]
    for proc in both:
        assert proc.wait(timeout=15) == 0
    time.sleep(0.5)   # a dispatch that raced would start its Waybar by now
    assert Path(env["T"], "running").read_text().splitlines() == ["w"]
