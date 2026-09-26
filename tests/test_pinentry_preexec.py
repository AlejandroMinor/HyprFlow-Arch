"""Tests for dotconfig/pinentry/preexec, which Arch's /usr/bin/pinentry
sources before picking a backend: the Qt one when installed, else nothing."""

import os
import subprocess
from pathlib import Path

PREEXEC = Path(__file__).resolve().parent.parent / "dotconfig" / "pinentry" / "preexec"

# Stands in for the wrapper: source the hook, then fall back as it would.
WRAPPER = f'. "{PREEXEC}"; echo "fallback $*"'


def run(tmp_path, with_qt):
    fakes = tmp_path / "fakebin"
    fakes.mkdir(exist_ok=True)
    qt = fakes / "pinentry-qt"
    if with_qt:
        qt.write_text('#!/bin/bash\necho "qt $*"\n')
        qt.chmod(0o755)
    elif qt.exists():
        qt.unlink()
    env = {**os.environ, "PATH": f"{fakes}:/usr/bin/nonexistent"}
    return subprocess.run(["/usr/bin/bash", "-c", WRAPPER, "pinentry", "--ttyname", "x"],
                          env=env, text=True, capture_output=True).stdout.strip()


def test_the_qt_prompt_is_used_when_installed(tmp_path):
    assert run(tmp_path, with_qt=True) == "qt --ttyname x"


def test_without_it_the_wrapper_carries_on(tmp_path):
    assert run(tmp_path, with_qt=False) == "fallback --ttyname x"
