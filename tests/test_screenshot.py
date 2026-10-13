"""Tests for lib/screenshot.sh. It runs from a copy next to common.sh in a
temp folder, with fake hyprshot/satty/notify-send on PATH, so no screen is
touched and no real notification is shown."""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent


class Shot:
    def __init__(self, root):
        self.root = root
        self.lib = root / "lib"
        self.lib.mkdir()
        (root / "fakebin").mkdir()
        shutil.copy(REPO / "lib" / "screenshot.sh", self.lib)
        shutil.copy(REPO / "lib" / "common.sh", self.lib)
        # FAKE_NO_SHOT: the pick was cancelled, nothing comes out.
        self.fake(root / "fakebin" / "hyprshot",
                  '[ -n "${FAKE_NO_SHOT:-}" ] || echo PNG')
        self.fake(root / "fakebin" / "satty", r'''
while [ $# -gt 0 ]; do
    [ "$1" = "--output-filename" ] && { out="$2"; shift; }
    [ "$1" = "--copy-command" ] && { copy="$2"; shift; }
    shift
done
[ -n "${FAKE_CANCEL:-}" ] && exit 0
# FAKE_COPY: copied instead of saved, through satty's copy command.
[ -n "${FAKE_COPY:-}" ] && { echo PNG | $copy; exit 0; }
[ -n "${FAKE_SAVE_AS:-}" ] && out="$FAKE_SAVE_AS"
: > "$out"
echo "File saved to '$out'." 1>&2
''')
        self.fake(root / "fakebin" / "notify-send", "")
        self.fake(root / "fakebin" / "qs", "")
        self.fake(root / "fakebin" / "wl-copy", 'cat > "$T/clip"')
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("XDG_", "HYPRLAND_"))}
        self.env.update(T=str(root), HOME=str(root), XDG_RUNTIME_DIR=str(root),
                        PATH=f"{root / 'fakebin'}:{os.environ['PATH']}")

    @staticmethod
    def fake(path, body):
        path.write_text(f'#!/bin/bash\necho "{path.name} $*" >> "$T/log"\n{body}\n')
        path.chmod(0o755)

    def run(self, *args, **env):
        (self.root / "log").write_text("")
        return subprocess.run([str(self.lib / "screenshot.sh"), *args], text=True,
                              capture_output=True, env={**self.env, **env}, timeout=30)

    def log(self):
        return (self.root / "log").read_text().splitlines()

    def previews(self):
        return sorted(self.root.glob("hyprflow-shot-*.png"))

    def shots(self):
        return sorted((self.root / "Pictures" / "Screenshots").glob("*.png"))


@pytest.fixture
def shot(tmp_path):
    return Shot(tmp_path)


def test_a_saved_shot_is_announced_as_a_preview_with_an_open_button(shot):
    shot.run("region")
    [out] = shot.shots()
    assert any(line == "hyprshot -m region --freeze --raw" for line in shot.log())
    assert any(line.startswith("satty") and "--early-exit all" in line
               and "--action-on-enter save-to-file" in line
               and f"--output-filename {out}" in line and "--disable-notifications" in line
               for line in shot.log())
    assert any(line.startswith("notify-send -a Screenshot") and f"-i {out}" not in line
               and "-t 8000" in line and "-A open=Open" in line
               and f'<img src="file://{out}">{out}' in line
               for line in shot.log())


def test_a_shot_saved_elsewhere_is_announced_where_it_landed(shot):
    # "Save as" writes to a path the user picked, not --output-filename, so the
    # toast must follow satty's "File saved to '<path>'." report.
    elsewhere = shot.root / "otro.png"
    shot.run("region", FAKE_SAVE_AS=str(elsewhere))
    assert any(line.startswith("notify-send -a Screenshot")
               and f'<img src="file://{elsewhere}">{elsewhere}' in line
               for line in shot.log())


def test_a_cancelled_shot_says_nothing(shot):
    shot.run("region", FAKE_CANCEL="1")
    assert not shot.shots()
    assert not any(line.startswith("notify-send") for line in shot.log())


def test_the_clipboard_takes_the_shot_without_satty(shot):
    shot.run("region", "--clipboard")
    [preview] = shot.previews()
    assert shot.log() == ["hyprshot -m region --freeze --raw",
                          "wl-copy --type image/png",
                          f'notify-send -a Screenshot -i camera-photo-symbolic -t 3000 -- Screenshot <img src="file://{preview}">Copied to clipboard']
    assert (shot.root / "clip").read_text() == "PNG\n"


def test_a_cancelled_clipboard_shot_says_nothing(shot):
    shot.run("region", "--clipboard", FAKE_NO_SHOT="1")
    assert shot.log() == ["hyprshot -m region --freeze --raw"]


def test_clipboard_freezes_the_screen_too(shot):
    shot.run("window", "--clipboard")
    assert shot.log()[0] == "hyprshot -m window --freeze --raw"


def test_a_copy_from_satty_says_copied(shot):
    shot.run("region", FAKE_COPY="1")
    [preview] = shot.previews()
    assert shot.shots() == []
    assert shot.log()[-1] == (f'notify-send -a Screenshot -i camera-photo-symbolic -t 3000 -- '
                              f'Screenshot <img src="file://{preview}">Copied to clipboard')
    assert (shot.root / "clip").read_text() == "PNG\n"


def test_a_cancel_after_an_earlier_copy_stays_quiet(shot):
    shot.run("region", FAKE_COPY="1")
    shot.run("region", FAKE_CANCEL="1")
    assert not any(line.startswith("notify-send") for line in shot.log())


def test_each_copy_keeps_its_own_preview(shot):
    shot.run("region", "--clipboard")
    shot.run("region", "--clipboard")
    assert len(shot.previews()) == 2


def test_day_old_previews_are_cleaned_up(shot):
    old = shot.root / "hyprflow-shot-1.png"
    old.write_text("OLD")
    os.utime(old, (0, 0))
    shot.run("region", "--clipboard")
    assert not old.exists() and len(shot.previews()) == 1
