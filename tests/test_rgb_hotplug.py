"""Tests for lib/rgb-hotplug.py. udevadm and rgb-sync.sh are never run: the
lines are fed in, and the timer and rescan are fakes."""

ADD = "UDEV  [5123.456789] add      /devices/pci0000:00/0000:14:00.3/usb3/3-1 (usb)\n"
REMOVE = "UDEV  [5130.000000] remove   /devices/pci0000:00/0000:14:00.3/usb3/3-1 (usb)\n"


class FakeTimer:
    started = []

    def __init__(self, delay, action):
        self.delay, self.action, self.cancelled = delay, action, False
        FakeTimer.started.append(self)

    def start(self):
        pass

    def cancel(self):
        self.cancelled = True


def hotplug(rgb_hotplug):
    FakeTimer.started = []
    calls = []
    return rgb_hotplug.Hotplug(rescan=lambda: calls.append(1), timer=FakeTimer), calls


def test_a_device_added_rescans_after_it_settles(rgb_hotplug):
    watch, calls = hotplug(rgb_hotplug)
    watch.line(ADD)
    [timer] = FakeTimer.started
    assert timer.delay == rgb_hotplug.SETTLE
    timer.action()
    assert calls == [1]


def test_a_burst_of_events_is_one_rescan(rgb_hotplug):
    watch, _ = hotplug(rgb_hotplug)
    for _ in range(3):
        watch.line(ADD)
    assert [t.cancelled for t in FakeTimer.started] == [True, True, False]


def test_removals_and_the_header_are_ignored(rgb_hotplug):
    watch, _ = hotplug(rgb_hotplug)
    for line in ["monitor will print the received events for:\n",
                 "UDEV - the event which udev sends out after rule processing\n",
                 "\n", REMOVE]:
        watch.line(line)
    assert FakeTimer.started == []


def test_rescan_runs_rgb_sync_detached(rgb_hotplug, monkeypatch):
    seen = []
    monkeypatch.setattr(rgb_hotplug.subprocess, "Popen", lambda argv, **k: seen.append((argv, k)))
    rgb_hotplug.rescan()
    argv, kwargs = seen[0]
    assert argv[0].endswith("bin/rgb-sync.sh") and argv[1:] == ["--rescan"]
    assert kwargs["start_new_session"]
