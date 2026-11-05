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
    assert set(calls(env)) == {
        f"--config {config}/config.jsonc --file {config}/ascii_art/skull.txt",
        f"--config {config}/config.jsonc --kitty {config}/img_art/knight.png",
        f"--config {config}/config.jsonc --logo-type builtin --logo arch",
    }


def test_a_linked_clone_adds_its_logos_but_not_the_originals(home):
    root, env = home
    config = root / ".config" / "fastfetch"
    clone = root / "Projects" / "fastfetch"
    for folder in ("ascii_art", "images/originals", "images/resized", "gifs/originals",
                   "gifs/resized", "tools", ".git"):
        (clone / folder).mkdir(parents=True)
    (clone / "README.md").write_text("docs")
    (clone / "ascii_art" / "skull.txt").write_text("x\n")  # same name as the reference one
    (clone / "images" / "originals" / "wizard.png").write_bytes(b"big png")
    (clone / "images" / "resized" / "wizard.png").write_bytes(b"png")
    (clone / "gifs" / "originals" / "fire.gif").write_bytes(b"big gif")
    (clone / "gifs" / "resized" / "fire.gif").write_bytes(b"gif")
    (clone / "tools" / "notes.txt").write_text("not a logo")
    (clone / ".git" / "description.txt").write_text("not a logo")
    (config / "logos").symlink_to(clone)
    logos = config / "logos"
    assert set(calls(env, 80)) == {
        f"--config {config}/config.jsonc --file {config}/ascii_art/skull.txt",
        f"--config {config}/config.jsonc --kitty {config}/img_art/knight.png",
        f"--config {config}/config.jsonc --kitty {logos}/images/resized/wizard.png",
        f"--config {config}/config.jsonc --kitty {logos}/gifs/resized/fire.gif --logo-animation-frame 0",
        f"--config {config}/config.jsonc --logo-type builtin --logo arch",
    }


def test_it_does_not_depend_on_where_the_repo_was_cloned(home):
    _, env = home
    assert not any("HyprFlow-Arch" in call for call in calls(env, 10))
