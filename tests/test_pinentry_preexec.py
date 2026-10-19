"""Tests for dotconfig/pinentry/preexec, which Arch's /usr/bin/pinentry
sources before picking a backend: curses for a terminal without a display,
the Qt one when installed, else nothing."""

import os
import subprocess
from pathlib import Path

PREEXEC = Path(__file__).resolve().parent.parent / "dotconfig" / "pinentry" / "preexec"

# Stands in for the wrapper: source the hook, then fall back as it would.
WRAPPER = f'. "{PREEXEC}"; echo "fallback $*"'


def run(tmp_path, with_qt, user_data="gui"):
    fakes = tmp_path / "fakebin"
    fakes.mkdir(exist_ok=True)
    qt = fakes / "pinentry-qt"
    if with_qt:
        qt.write_text('#!/bin/bash\necho "qt $*"\n')
        qt.chmod(0o755)
    elif qt.exists():
        qt.unlink()
    env = {**os.environ, "PATH": f"{fakes}:/usr/bin/nonexistent", "PINENTRY_USER_DATA": user_data}
    return subprocess.run(["/usr/bin/bash", "-c", WRAPPER, "pinentry", "--ttyname", "x"],
                          env=env, text=True, capture_output=True).stdout.strip()


def test_the_qt_prompt_is_used_when_installed(tmp_path):
    assert run(tmp_path, with_qt=True) == "qt --ttyname x"


def test_without_it_the_wrapper_carries_on(tmp_path):
    assert run(tmp_path, with_qt=False) == "fallback --ttyname x"


def test_a_terminal_without_a_display_gets_curses(tmp_path):
    # The hook execs the real pinentry-curses; asking it its flavour is enough.
    out = subprocess.run(["/usr/bin/bash", "-c", f'. "{PREEXEC}"', "pinentry"],
                         input="GETINFO flavor\nBYE\n", text=True, capture_output=True,
                         env={**os.environ, "PINENTRY_USER_DATA": "tty"}).stdout
    assert "D curses" in out
