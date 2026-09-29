"""Tests for dotconfig/hypr/hyprlock/geometry.sh: the two files hyprlock
sources. It runs from a copy, against a throwaway config dir and a fake
hyprctl reporting one monitor, so the real lockscreen is never touched."""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
MONITOR = {"name": "TEST-A", "width": 2560, "height": 1440, "scale": 1.0, "transform": 0}


@pytest.fixture
def lock(tmp_path):
    scripts = tmp_path / "config" / "hypr" / "hyprlock"
    shutil.copytree(REPO / "dotconfig" / "hypr" / "hyprlock", scripts)
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    bodies = {
        "hyprctl": f"""case "$1" in
            monitors) echo '{json.dumps([MONITOR])}' ;;
            workspaces) echo '[{{"id": 1, "monitor": "TEST-A"}}]' ;;
        esac""",
        "awww": "",
    }
    for name, body in bodies.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND_"))}
    env.update(HOME=str(tmp_path), XDG_CONFIG_HOME=str(tmp_path / "config"),
               XDG_CACHE_HOME=str(tmp_path / "cache"), PATH=f"{fakes}:{os.environ['PATH']}")

    def run():
        return subprocess.run(["bash", str(scripts / "geometry.sh")], env=env,
                              capture_output=True, text=True, timeout=60)

    return run, tmp_path / "config" / "hypr", fakes


def test_it_writes_both_files_and_leaves_no_temporary_ones(lock):
    run, hypr, _ = lock
    result = run()
    assert result.returncode == 0, result.stderr
    assert (hypr / "hyprlock-geometry.conf").read_text().strip()
    assert "background {" in (hypr / "hyprlock-extras.conf").read_text()
    assert sorted(p.name for p in hypr.glob("hyprlock-*.conf*")) == [
        "hyprlock-extras.conf", "hyprlock-geometry.conf"]


def test_a_failed_run_leaves_the_previous_files_whole(lock):
    run, hypr, fakes = lock
    for name in ("hyprlock-geometry.conf", "hyprlock-extras.conf"):
        (hypr / name).write_text("previous\n")
    # The last step fails, as a full disk would: nothing may be half written.
    (fakes / "mv").write_text("#!/bin/bash\nexit 1\n")
    (fakes / "mv").chmod(0o755)
    assert run().returncode != 0
    assert (hypr / "hyprlock-geometry.conf").read_text() == "previous\n"
    assert (hypr / "hyprlock-extras.conf").read_text() == "previous\n"
    assert sorted(p.name for p in hypr.glob("hyprlock-*.conf*")) == [
        "hyprlock-extras.conf", "hyprlock-geometry.conf"]
