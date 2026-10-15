"""Tests for bin/sinkswitch, the short name for lib/sink-switch.py. It runs
from a copy in a temp folder with a stub lib script, so nothing is read from
PipeWire or switched."""

import shutil
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def test_the_command_runs_the_lib_script_with_the_arguments(tmp_path):
    (tmp_path / "bin").mkdir()
    (tmp_path / "lib").mkdir()
    shutil.copy(REPO / "bin" / "sinkswitch", tmp_path / "bin")
    stub = tmp_path / "lib" / "sink-switch.py"
    stub.write_text('import sys\nprint("stub", *sys.argv[1:])\n')

    result = subprocess.run([str(tmp_path / "bin" / "sinkswitch"), "--json", "--set", "66"],
                            text=True, capture_output=True, timeout=30)

    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "stub --json --set 66"
