"""Tests for bin/rgb-sync.sh: the colour it picks, read back from the cache
file it writes before talking to OpenRGB. openrgb itself is a fake."""

import os
import subprocess
from pathlib import Path

import pytest
from PIL import Image

SCRIPT = Path(__file__).resolve().parent.parent / "bin" / "rgb-sync.sh"
GREYS = {f"color{i}": "#808080" for i in range(16)}


@pytest.fixture
def rgb(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    (fakes / "openrgb").write_text('#!/bin/bash\necho "openrgb $*" >> "$HOME/log"\n')
    (fakes / "openrgb").chmod(0o755)
    (tmp_path / ".cache" / "wallust" / "colors").mkdir(parents=True)
    env = {**os.environ, "HOME": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}"}

    def run(*args, palette=None, path=None):
        if palette is not None:
            text = "".join(f"{k}='{v}'\n" for k, v in {**GREYS, **palette}.items())
            (tmp_path / ".cache/wallust/colors/colors-rofi-sh.conf").write_text(text)
        subprocess.run(["/usr/bin/bash", str(SCRIPT), *args], env=env if path is None else {**env, "PATH": path},
                       check=True, timeout=30)
        cache = tmp_path / ".cache/wallust/led-color"
        return cache.read_text().strip() if cache.exists() else None

    return run, tmp_path


def image(path, *areas):
    """A picture split in vertical bands: (colour, share of the width)."""
    img, x = Image.new("RGB", (100, 100)), 0
    for colour, share in areas:
        img.paste(colour, (x, 0, x + share, 100))
        x += share
    img.save(path)
    return str(path)


def test_the_accent_is_pushed_to_full_saturation(rgb):
    run, _ = rgb
    # #778D01: min 1, max 141 -> each channel stretched over [1, 141].
    assert run(palette={"color5": "#778D01"}) == "D6FF00"


def test_a_grey_accent_gives_way_to_the_most_colourful_palette_entry(rgb):
    run, _ = rgb
    assert run(palette={"color5": "#777777", "color9": "#203040", "color12": "#E02010"}) == "FF1300"


def test_an_all_grey_palette_goes_white(rgb):
    run, _ = rgb
    assert run(palette={}) == "FFFFFF"


def test_the_wallpaper_hue_covering_the_most_area_wins(rgb):
    run, root = rgb
    wall = image(root / "wall.png", ((20, 40, 230), 70), ((230, 30, 20), 30))
    r, g, b = bytes.fromhex(run(wall, palette={"color5": "#778D01"}))
    assert b == 255 and r < 60 and g < 100


def test_a_wallpaper_with_no_real_colour_goes_white(rgb):
    run, root = rgb
    assert run(image(root / "grey.png", ((90, 90, 90), 100)), palette={}) == "FFFFFF"


def test_a_video_wallpaper_falls_back_to_the_palette(rgb):
    run, root = rgb
    (root / "clip.mp4").write_bytes(b"not an image")
    assert run(str(root / "clip.mp4"), palette={"color5": "#778D01"}) == "D6FF00"


def test_last_reuses_the_cached_colour(rgb):
    run, root = rgb
    run(palette={"color5": "#778D01"})
    (root / ".cache/wallust/colors/colors-rofi-sh.conf").unlink()
    assert run("--last") == "D6FF00"


def test_without_openrgb_it_does_nothing(rgb):
    run, root = rgb
    # An empty PATH: /bin is /usr/bin on Arch, so leaving it in would find the
    # real openrgb and repaint the real LEDs.
    (root / "empty").mkdir()
    assert run(palette={"color5": "#778D01"}, path=str(root / "empty")) is None
