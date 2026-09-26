"""Tests for lib/camera_status.py. /dev and /proc are faked, and inotify
events are built by hand, so no camera or running process is needed."""

import json

import pytest


def event(camera, mask, name=b""):
    """One raw inotify event as the kernel lays it out (name NUL padded)."""
    padded = name + b"\0" * (16 - len(name)) if name else b""
    return camera.EVENT_HEADER.pack(1, mask, 0, len(padded)) + padded


@pytest.fixture
def fake_system(camera, monkeypatch):
    """/dev with two cameras and a tty; /proc with three processes, one of
    them (1001) holding /dev/video0 open, one that vanished mid-scan."""
    dirs = {
        "/dev": ["video0", "video1", "tty1", "null"],
        "/proc": ["1", "1001", "2002", "self", "cpuinfo"],
        "/proc/1": None,                           # not ours: PermissionError
        "/proc/1001/fd": ["0", "1", "5"],
        "/proc/2002/fd": ["0"],
    }
    links = {
        "/proc/1001/fd/0": "/dev/null",
        "/proc/1001/fd/1": "pipe:[123]",
        "/proc/1001/fd/5": "/dev/video0",
        "/proc/2002/fd/0": "/dev/tty1",
    }

    def listdir(path):
        if path == "/proc/1/fd":
            raise PermissionError(path)
        if path not in dirs:
            raise FileNotFoundError(path)
        return dirs[path]

    def readlink(path):
        if path not in links:
            raise OSError(path)
        return links[path]

    monkeypatch.setattr(camera.os, "listdir", listdir)
    monkeypatch.setattr(camera.os, "readlink", readlink)
    return dirs, links


def test_video_devices_are_only_the_video_nodes(camera, fake_system):
    assert camera.video_devices() == {"/dev/video0", "/dev/video1"}


def test_finds_the_process_holding_a_camera(camera, fake_system):
    assert camera.check_camera() == "/dev/video0"


def test_no_camera_open(camera, fake_system):
    _, links = fake_system
    links["/proc/1001/fd/5"] = "/dev/null"
    assert camera.check_camera() is None


def test_state_active_shows_the_camera_icon(camera, fake_system):
    state = camera.state()
    assert state["class"] == "active"
    assert state["text"] == " "          # the icon the rewrite once lost
    assert "/dev/video0" in state["tooltip"]
    json.dumps(state)                          # Waybar gets it as JSON


def test_state_inactive_is_empty(camera, fake_system):
    _, links = fake_system
    del links["/proc/1001/fd/5"]
    assert camera.state() == {"text": "", "class": "inactive"}


@pytest.mark.parametrize("mask, name", [
    ("IN_CREATE", b"video2"),   # camera plugged in
    ("IN_DELETE", b"video0"),   # camera unplugged
    ("IN_ATTRIB", b"video2"),   # udev granted access to it
])
def test_video_node_changes_ask_for_new_watches(camera, mask, name):
    assert camera.video_event(event(camera, getattr(camera, mask), name))


@pytest.mark.parametrize("data", [
    lambda c: event(c, c.IN_OPEN),                     # a camera opened (watched file, no name)
    lambda c: event(c, c.IN_CLOSE_NOWRITE),            # and closed
    lambda c: event(c, c.IN_CREATE, b"tty5"),          # another device in /dev
])
def test_other_events_do_not(camera, data):
    assert not camera.video_event(data(camera))


def test_a_batch_with_one_video_event_among_others(camera):
    batch = (event(camera, camera.IN_OPEN) + event(camera, camera.IN_CREATE, b"tty5")
             + event(camera, camera.IN_CREATE, b"video3"))
    assert camera.video_event(batch)
