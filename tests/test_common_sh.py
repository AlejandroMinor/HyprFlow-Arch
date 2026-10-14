"""Tests for lib/common.sh, sourced by the shell scripts."""

import os
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def bash(script, tmp_path, **env):
    fakes = tmp_path / "fakebin"
    fakes.mkdir(exist_ok=True)
    (fakes / "notify-send").write_text('#!/bin/bash\necho "notify-send $*"\n')
    (fakes / "notify-send").chmod(0o755)
    # The Quickshell panel: logs the call and succeeds, or is not running
    # (exit 255) when QS_OFF is set.
    (fakes / "qs").write_text('#!/bin/bash\n[ -n "${QS_OFF:-}" ] && exit 255\necho "qs $*"\n')
    (fakes / "qs").chmod(0o755)
    full = {**os.environ, "PATH": f"{fakes}:{os.environ['PATH']}", **env}
    return subprocess.run(["bash", "-c", f'. "{REPO}/lib/common.sh"; {script}'],
                          env=full, text=True, capture_output=True)


def test_msg_and_warn_carry_the_scripts_name(tmp_path):
    result = bash('hyprflow_name "X" monitors 34 Monitors; msg hello; warn careful', tmp_path)
    assert result.stdout == "\x1b[1;34mX monitors:\x1b[0m hello\n"
    assert result.stderr == "\x1b[1;33mX monitors:\x1b[0m careful\n"


def test_notify_uses_the_title(tmp_path):
    result = bash('hyprflow_name "X" monitors 34 Monitors; notify "Layout changed"', tmp_path)
    assert result.stdout == "notify-send -a Monitors -- Monitors Layout changed\n"


def test_notify_text_starting_with_a_dash_is_not_an_option(tmp_path):
    result = bash('hyprflow_name "X" monitors 34 Monitors; notify "-1 monitor"', tmp_path)
    assert result.stdout == "notify-send -a Monitors -- Monitors -1 monitor\n"


def test_notify_takes_urgency_icon_timeout_and_an_action(tmp_path):
    result = bash('hyprflow_name "X" monitors 34 Monitors; '
                  'notify --urgency critical --icon battery-low --timeout 0 '
                  '--transient --replace 4 --category device --action power=Power "Low battery"', tmp_path)
    assert result.stdout == ("notify-send -a Monitors -u critical -i battery-low -t 0 -e -r 4 "
                             "-c device -A power=Power -- Monitors Low battery\n")


def test_notify_with_an_action_does_not_wait_for_the_user(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    (fakes / "notify-send").write_text("#!/bin/bash\nsleep 30\n")
    (fakes / "notify-send").chmod(0o755)
    full = {**os.environ, "PATH": f"{fakes}:{os.environ['PATH']}"}
    result = subprocess.run(
        ["bash", "-c", f'. "{REPO}/lib/common.sh"; hyprflow_name "X" monitors 34; '
                      'notify --action open=Open "Saved"'],
        env=full, text=True, capture_output=True, timeout=10)
    assert result.returncode == 0


def test_load_palette_fills_the_callers_variables(tmp_path):
    palette = tmp_path / "palette.sh"
    palette.write_text("color5='#778D01'\n")
    result = bash('color5=default; load_palette; echo "$color5"', tmp_path, WALLUST_SH_PALETTE=str(palette))
    assert result.stdout == "#778D01\n"


def test_load_palette_without_one_keeps_the_defaults(tmp_path):
    result = bash('color5=default; load_palette || echo none; echo "$color5"', tmp_path,
                  WALLUST_SH_PALETTE=str(tmp_path / "missing"))
    assert result.stdout == "none\ndefault\n"


def test_osd_reaches_the_panel(tmp_path):
    result = bash('osd "I" "Volume" "50%" 50', tmp_path)
    assert result.stdout == "qs -c hyprflow ipc call osd level I Volume 50% 50\n"


def test_osd_is_false_when_quickshell_is_not_running(tmp_path):
    result = bash('osd "I" "Volume" "50%" 50 || echo fallback', tmp_path, QS_OFF="1")
    assert result.stdout == "fallback\n"


def test_quickshell_up_is_true_when_the_panel_runs(tmp_path):
    result = bash('quickshell_up && echo up', tmp_path)
    assert result.stdout.endswith("up\n")


def test_quickshell_up_is_false_when_the_panel_is_not_running(tmp_path):
    result = bash('quickshell_up || echo down', tmp_path, QS_OFF="1")
    assert result.stdout == "down\n"


def test_the_repo_folders_are_found_through_a_symlink(tmp_path):
    """Scripts run from ~/.local/bin links; common.sh still finds the repo."""
    link = tmp_path / "common.sh"
    link.symlink_to(REPO / "lib" / "common.sh")
    result = subprocess.run(["bash", "-c", f'. "{link}"; echo "$HYPRFLOW_LIB"; echo "$HYPRFLOW_BIN"'],
                            text=True, capture_output=True)
    assert result.stdout.split() == [str(REPO / "lib"), str(REPO / "bin")]
