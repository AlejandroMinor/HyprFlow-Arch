"""The README's Requirements table promises a minimum Python. vermin reads
every script in lib/ and fails this test when one needs anything newer, so a
stray newer feature is caught here and not on someone's machine. The number
lives only in the README. Skipped without vermin (.venv/bin/pip install vermin)."""

import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

# vermin is a command, not a runnable module: the one next to this Python.
BINARY = shutil.which("vermin", path=str(Path(sys.executable).parent)) or shutil.which("vermin")
if BINARY is None:
    pytest.skip("vermin is not installed", allow_module_level=True)

REPO = Path(__file__).resolve().parent.parent
LIB = REPO / "lib"
# The Minimum column of the README's Python row: | Python | tested | minimum | why |
MINIMUM = re.search(r"^\| Python \|[^|]*\| *([0-9.]+) *\|", (REPO / "README.md").read_text(), re.M).group(1)

# --eval-annotations and union-types: `X | None` in a signature is evaluated
# when the function is defined, so it counts. Off by default in vermin.
VERMIN = [BINARY, "--no-tips", "--eval-annotations",
          "--feature", "union-types", "--violations", f"-t={MINIMUM}-"]


def test_lib_runs_on_the_minimum_python():
    result = subprocess.run([*VERMIN, str(LIB)], capture_output=True, text=True, timeout=120)
    assert result.returncode == 0, result.stdout + result.stderr


def test_the_readme_names_a_minimum():
    assert re.fullmatch(r"3\.\d+", MINIMUM)


def test_the_check_would_catch_a_newer_feature(tmp_path):
    (tmp_path / "newer.py").write_text("import tomllib\n")   # 3.11
    result = subprocess.run([*VERMIN, str(tmp_path)], capture_output=True, text=True, timeout=60)
    assert result.returncode != 0 and "tomllib" in result.stdout and "3.11" in result.stdout
