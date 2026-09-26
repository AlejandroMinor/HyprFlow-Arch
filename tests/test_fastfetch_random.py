"""Tests for lib/fastfetch-random.sh, with a fake fastfetch that logs its
arguments and a throwaway $HOME holding the logos."""

import os
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "lib" / "fastfetch-random.sh"


@pytest.fixture
def home(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    fake = fakes / "fastfetch"
    fake.write_text('#!/bin/bash\necho "$*"\n')
    fake.chmod(0o755)
    config = tmp_path / ".config" / "fastfetch"
    (config / "ascii_art").mkdir(parents=True)
    (config / "img_art").mkdir()
    (config / "ascii_art" / "skull.txt").write_text("x\n")
    (config / "img_art" / "knight.png").write_bytes(b"png")
    env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "FASTFETCH_"))}
    env.update(HOME=str(tmp_path), PATH=f"{fakes}:{os.environ['PATH']}")
    return tmp_path, env


def calls(env, times=40):
    return [subprocess.run(["bash", str(SCRIPT)], env=env, text=True, capture_output=True,
                           check=True).stdout.strip() for _ in range(times)]


def test_logos_come_from_the_installed_config(home):
    root, env = home
    config = root / ".config" / "fastfetch"
    seen = set(calls(env))
    assert f"--config {config}/config.jsonc --file {config}/ascii_art/skull.txt" in seen
    assert f"--config {config}/config.jsonc --kitty {config}/img_art/knight.png" in seen
    assert f"--config {config}/config.jsonc --logo-type builtin --logo arch" in seen


def test_it_does_not_depend_on_where_the_repo_was_cloned(home):
    _, env = home
    assert not any("HyprFlow-Arch" in call for call in calls(env, 10))
