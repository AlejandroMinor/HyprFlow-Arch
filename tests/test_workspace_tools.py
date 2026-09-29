"""Tests for the keybinding helpers that act on a whole workspace:
close-workspace.sh (Super+Shift+Q), hyprland-show-desktop.sh (Super+D) and
hyprland-group-all.sh (Super+Shift+G). hyprctl and rofi are fakes that log
what they were asked, so no real window moves."""

import json
import os
import subprocess
from pathlib import Path

import pytest

LIB = Path(__file__).resolve().parent.parent / "lib"

HYPRCTL = r'''
if [ "$1" = "--batch" ]; then printf '%s\n' "$2" >> "$T/batch"; exit 0; fi
case "$1" in
    activeworkspace) cat "$T/active.json" ;;
    clients)         cat "$T/clients.json" ;;
    monitors)        cat "$T/monitors.json" ;;
esac
'''


@pytest.fixture
def box(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    for name, body in {"hyprctl": HYPRCTL,
                       "rofi": 'cat > "$T/offered"; printf "%s\\n" "${FAKE_ANSWER:-}"'}.items():
        (fakes / name).write_text(f"#!/bin/bash\n{body}\n")
        (fakes / name).chmod(0o755)
    (tmp_path / "active.json").write_text(json.dumps({"id": 3, "monitor": "DP-2"}))
    (tmp_path / "clients.json").write_text(json.dumps([
        {"address": "0xa", "workspace": {"id": 3}, "mapped": True},
        {"address": "0xb", "workspace": {"id": 3}, "mapped": True},
        {"address": "0xc", "workspace": {"id": 5}, "mapped": True},
        {"address": "0xd", "workspace": {"id": 3}, "mapped": False},
    ]))
    (tmp_path / "monitors.json").write_text(json.dumps([
        {"name": "HDMI-A-1", "activeWorkspace": {"id": 3}},
        {"name": "DP-2", "activeWorkspace": {"id": 1}},
    ]))
    env = {**os.environ, "T": str(tmp_path), "HOME": str(tmp_path), "XDG_RUNTIME_DIR": str(tmp_path),
           "PATH": f"{fakes}:{os.environ['PATH']}"}

    def run(script, **extra):
        subprocess.run(["bash", str(LIB / script)], env={**env, **extra}, check=True, timeout=10,
                       capture_output=True)
        batch = tmp_path / "batch"
        out = batch.read_text() if batch.exists() else ""
        batch.unlink(missing_ok=True)
        return out

    return run, tmp_path


def test_close_workspace_asks_and_closes_only_this_workspace(box):
    run, root = box
    batch = run("close-workspace.sh", FAKE_ANSWER="Close 2 window(s)")
    assert (root / "offered").read_text().splitlines() == ["Cancel", "Close 2 window(s)"]
    assert "address:0xa" in batch and "address:0xb" in batch
    assert "0xc" not in batch and "0xd" not in batch       # other workspace, unmapped
    assert batch.count("hl.dsp.window.close()") == 2


def test_close_workspace_cancel_closes_nothing(box):
    run, _ = box
    assert run("close-workspace.sh", FAKE_ANSWER="Cancel") == ""


def test_close_workspace_on_an_empty_workspace_does_not_ask(box):
    run, root = box
    (root / "active.json").write_text(json.dumps({"id": 9}))
    assert run("close-workspace.sh", FAKE_ANSWER="Close 0 window(s)") == ""
    assert not (root / "offered").exists()


def test_show_desktop_sends_every_monitor_to_a_decoy_and_back(box):
    run, root = box
    hide = run("hyprland-show-desktop.sh")
    assert 'focus({monitor = "HDMI-A-1"}); dispatch hl.dsp.focus({workspace = 901})' in hide
    assert 'focus({monitor = "DP-2"}); dispatch hl.dsp.focus({workspace = 902})' in hide
    assert (root / "hyprland-show-desktop.json").exists()

    back = run("hyprland-show-desktop.sh")
    assert 'focus({monitor = "HDMI-A-1"}); dispatch hl.dsp.focus({workspace = 3})' in back
    assert 'focus({monitor = "DP-2"}); dispatch hl.dsp.focus({workspace = 1})' in back
    assert back.rstrip().endswith('dispatch hl.dsp.focus({monitor = "DP-2"});')   # focus returns
    assert not (root / "hyprland-show-desktop.json").exists()


def test_show_desktop_sends_only_real_monitors_and_numbers_back(box):
    run, root = box
    (root / "hyprland-show-desktop.json").write_text(json.dumps({
        "monitors": {"HDMI-A-1": 3, 'DP-2"}) os.execute("x") --': 1, "DP-2": "1; evil"},
        "focused_monitor": "GONE-1"}))
    back = run("hyprland-show-desktop.sh")
    assert back.strip() == 'dispatch hl.dsp.focus({monitor = "HDMI-A-1"}); dispatch hl.dsp.focus({workspace = 3});'
    assert not (root / "hyprland-show-desktop.json").exists()


def test_show_desktop_keeps_the_state_when_the_restore_fails(box):
    run, root = box
    state = root / "hyprland-show-desktop.json"
    state.write_text(json.dumps({"monitors": {"DP-2": 1}, "focused_monitor": "DP-2"}))
    (root / "fakebin" / "hyprctl").write_text("#!/bin/bash\n" + HYPRCTL.replace(
        'printf \'%s\\n\' "$2" >> "$T/batch"; exit 0', 'exit 1'))
    run("hyprland-show-desktop.sh")
    assert state.exists()


def test_show_desktop_refuses_to_run_without_a_runtime_dir(box):
    _, root = box
    # The fakes stay first on PATH: a script that did not refuse would
    # otherwise reach the real hyprctl and hide the real desktop.
    env = {k: v for k, v in os.environ.items() if k != "XDG_RUNTIME_DIR"}
    env.update(T=str(root), HOME=str(root), PATH=f"{root / 'fakebin'}:{os.environ['PATH']}")
    result = subprocess.run(["bash", str(LIB / "hyprland-show-desktop.sh")], env=env,
                            capture_output=True, text=True, timeout=10)
    assert result.returncode == 1 and "XDG_RUNTIME_DIR" in result.stderr
    assert not (root / "batch").exists()          # nothing was dispatched


def test_group_all_groups_the_workspace_windows(box):
    run, _ = box
    batch = run("hyprland-group-all.sh")
    assert batch.startswith("dispatch hl.dsp.focus({window = 'address:0xa'}); dispatch hl.dsp.group.toggle();")
    assert "address:0xb" in batch and "address:0xc" not in batch


def test_group_all_needs_two_windows(box):
    run, root = box
    (root / "active.json").write_text(json.dumps({"id": 5}))
    assert run("hyprland-group-all.sh") == ""
