"""Tests for bin/rgb-sync.sh: the colour it picks, read back from the cache
file it writes before talking to OpenRGB. openrgb itself is a fake."""

import os
import socket
import struct
import subprocess
import threading
from pathlib import Path

import pytest
from PIL import Image

SCRIPT = Path(__file__).resolve().parent.parent / "bin" / "rgb-sync.sh"
GREYS = {f"color{i}": "#808080" for i in range(16)}


# What OpenRGB 1.0 prints for -ld (-l lists names only since 1.0).
DETAILED = """0: ENE DRAM
  Modes: Direct Off [Static] Breathing Rainbow
1: Razer Basilisk V3
  Modes: Direct [Static] Breathing 'Spectrum Cycle'
"""


@pytest.fixture
def rgb(tmp_path):
    fakes = tmp_path / "fakebin"
    fakes.mkdir()
    (tmp_path / "detailed").write_text(DETAILED)
    (fakes / "openrgb").write_text('#!/bin/bash\necho "openrgb $*" >> "$HOME/log"\n'
                                   '[ "$1" = -ld ] && cat "$HOME/detailed"\nexit 0\n')
    (fakes / "openrgb").chmod(0o755)
    # A stand-in for the OpenRGB server port: never the real one, which is up
    # on this machine and would make the tests depend on it.
    server = socket.socket()
    server.bind(("127.0.0.1", 0))
    server.listen(16)
    # OpenRGB "not running": the script must not sit in its startup wait, and on
    # this machine the real service is up and listening on the port.
    (fakes / "systemctl").write_text("#!/bin/bash\nexit 1\n")
    (fakes / "systemctl").chmod(0o755)
    (tmp_path / ".cache" / "wallust" / "colors").mkdir(parents=True)
    env = {**os.environ, "HOME": str(tmp_path), "PATH": f"{fakes}:{os.environ['PATH']}",
           "RGB_PORT": str(server.getsockname()[1])}

    def run(*args, palette=None, path=None):
        if palette is not None:
            text = "".join(f"{k}='{v}'\n" for k, v in {**GREYS, **palette}.items())
            (tmp_path / ".cache/wallust/colors/colors-rofi-sh.conf").write_text(text)
        subprocess.run(["/usr/bin/bash", str(SCRIPT), *args], env=env if path is None else {**env, "PATH": path},
                       check=True, timeout=30)
        cache = tmp_path / ".cache/wallust/led-color"
        return cache.read_text().strip() if cache.exists() else None

    yield run, tmp_path
    server.close()


def log(root):
    path = root / "log"
    return path.read_text().splitlines() if path.exists() else []


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


@pytest.mark.parametrize("cached", ["", "zzz\n", "12345\n"])
def test_last_with_an_empty_or_damaged_cache_takes_the_palette(rgb, cached):
    run, root = rgb
    (root / ".cache/wallust/led-color").write_text(cached)
    assert run("--last", palette={"color5": "#778D01"}) == "D6FF00"


def test_a_palette_with_bad_entries_skips_them(rgb):
    run, root = rgb
    # A hand written wallust template with a short or missing colour.
    assert run(palette={"color5": "#777777", "color9": "#12", "color12": "#E02010"}) == "FF1300"


def test_without_openrgb_it_does_nothing(rgb):
    run, root = rgb
    # An empty PATH: /bin is /usr/bin on Arch, so leaving it in would find the
    # real openrgb and repaint the real LEDs.
    (root / "empty").mkdir()
    assert run(palette={"color5": "#778D01"}, path=str(root / "empty")) is None


def test_a_server_still_scanning_is_waited_for(rgb):
    """openrgb.service binds the port ~21 s into its hardware scan, and a
    session start landing in that window used to skip the LEDs until the next
    theme change. Active service, no port: retry, then give up quietly."""
    run, root = rgb
    probe = root / "fakebin/systemctl"
    probe.write_text('#!/bin/bash\necho poll >> "$HOME/polls"\nexit 0\n')
    probe.chmod(0o755)
    (root / ".cache/wallust/colors/colors-rofi-sh.conf").write_text("color5='#778D01'\n")
    env = {**os.environ, "HOME": str(root), "PATH": f"{root / 'fakebin'}:{os.environ['PATH']}",
           "RGB_WAIT_STEPS": "2", "RGB_PORT": "1"}   # nothing listens on port 1
    subprocess.run(["/usr/bin/bash", str(SCRIPT)], env=env, check=True, timeout=30)
    assert (root / "polls").read_text().split() == ["poll"] * 3   # polled, slept, gave up
    assert not (root / "log").exists()                           # gave up before openrgb


def test_off_reads_the_detailed_list_and_switches_every_device_off(rgb):
    run, root = rgb
    run("--off")
    assert "openrgb -ld" in log(root)
    # Off where the device has an Off mode, static black where it has none.
    assert "openrgb -d 0 -m off -d 1 -m static -c 000000" in log(root)
    assert (root / ".cache/wallust/led-off").exists()


def test_off_marks_nothing_when_no_device_came_back(rgb):
    run, root = rgb
    (root / "fakebin/openrgb").write_text('#!/bin/bash\necho "openrgb $*" >> "$HOME/log"\n')
    run("--off")                                          # an empty list, like -l on 1.0
    assert not (root / ".cache/wallust/led-off").exists()


def test_toggle_switches_off_then_back_to_the_last_colour(rgb):
    run, root = rgb
    run(palette={"color5": "#778D01"})                   # the theme colour, cached
    marker = root / ".cache/wallust/led-off"
    run("--toggle")
    assert marker.exists()                               # off
    assert run("--toggle") == "D6FF00" and not marker.exists()   # back, same colour


def test_a_new_colour_clears_the_off_mark(rgb):
    run, root = rgb
    run("--off")
    run(palette={"color5": "#778D01"})                   # a theme change turns them on
    assert not (root / ".cache/wallust/led-off").exists()


def openrgb_server(answer=True):
    """A stand-in OpenRGB server on its own port: records the packets it gets
    and, if answer, reports detection started and done after a rescan."""
    server = socket.socket()
    server.bind(("127.0.0.1", 0))
    server.listen(1)
    packets = []

    def serve():
        while True:   # server_up connects first, only to see the port open
            try:
                conn, _ = server.accept()
            except OSError:
                return
            with conn:
                while len(header := conn.recv(16, socket.MSG_WAITALL)) == 16:
                    packet, size = struct.unpack("<II", header[8:16])
                    if size:
                        conn.recv(size, socket.MSG_WAITALL)
                    packets.append(packet)
                    if packet == 140 and answer:
                        for reply in (101, 103):
                            conn.sendall(b"ORGB" + struct.pack("<III", 0, reply, 0))

    threading.Thread(target=serve, daemon=True).start()
    return server, packets


def rescan(root, port, wait="5"):
    env = {**os.environ, "HOME": str(root), "PATH": f"{root / 'fakebin'}:{os.environ['PATH']}",
           "RGB_PORT": str(port), "RGB_RESCAN_WAIT": wait}
    subprocess.run(["/usr/bin/bash", str(SCRIPT), "--rescan"], env=env, check=True, timeout=30)


def test_rescan_detects_again_then_applies_the_last_colour(rgb):
    run, root = rgb
    run(palette={"color5": "#778D01"})
    server, packets = openrgb_server()
    rescan(root, server.getsockname()[1])
    server.close()
    assert packets[-1] == 140                            # the rescan request
    assert log(root)[-1] == "openrgb -m static -c D6FF00"


def test_rescan_keeps_the_lights_off(rgb):
    run, root = rgb
    run("--off")
    server, _ = openrgb_server()
    rescan(root, server.getsockname()[1])
    server.close()
    assert log(root)[-1] == "openrgb -d 0 -m off -d 1 -m static -c 000000"


def test_rescan_with_a_silent_server_still_applies_the_colour(rgb):
    run, root = rgb
    run(palette={"color5": "#778D01"})
    server, _ = openrgb_server(answer=False)
    rescan(root, server.getsockname()[1], wait="1")
    server.close()
    assert log(root)[-1] == "openrgb -m static -c D6FF00"
