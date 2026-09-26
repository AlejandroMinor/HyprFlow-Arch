"""Tests for bin/pet-picker.sh: the CSS edit that switches the runner."""

import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "bin" / "pet-picker.sh"
CSS = Path(__file__).resolve().parent.parent / "dotconfig" / "waybar" / "runcat-runner.css"


def apply(css, font):
    return subprocess.run(["bash", "-c", f'source "{SCRIPT}"; apply_runner "{font}"'],
                          env={"RUNCAT_RUNNER_CSS": str(css), "PATH": "/usr/bin:/bin"},
                          capture_output=True, text=True)


def test_switching_rewrites_only_the_active_font(tmp_path):
    css = tmp_path / "runner.css"
    css.write_text(CSS.read_text())
    assert apply(css, "runcat-chicken").returncode == 0
    lines = css.read_text().splitlines()
    active = [l for l in lines if l.startswith("#custom-hardware-wrap ")]
    assert "font-family: 'runcat-chicken'" in active[0]
    # The commented alternative and the state colours are untouched.
    assert [l for l in lines if not l.startswith("#custom-hardware-wrap ")] == \
        [l for l in CSS.read_text().splitlines() if not l.startswith("#custom-hardware-wrap ")]


def test_a_css_without_the_runner_line_is_left_alone(tmp_path):
    css = tmp_path / "runner.css"
    css.write_text("#clock { color: red; }\n")
    result = apply(css, "runcat")
    assert result.returncode == 1
    assert "no #custom-hardware-wrap font-family line" in result.stderr
    assert css.read_text() == "#clock { color: red; }\n"
