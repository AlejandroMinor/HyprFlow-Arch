"""Tests for bin/battery-hub.py. Nothing here talks to UPower, headsetcontrol,
notify-send or Waybar: the adapters get fake input and the rest gets Devices."""

import json
import time

import pytest


class FakeSource:
    """Stands in for an adapter: returns the Devices it was given."""

    def __init__(self, devices):
        self.devices = devices

    def read(self):
        return self.devices


@pytest.fixture
def plain_palette(hub, tmp_path):
    """A palette with fixed colours, independent of the machine's wallust."""
    path = tmp_path / "colors.conf"
    path.write_text("color1='#ff0000'\ncolor3='#ffaa00'\ncolor6='#00ffff'\n")
    return hub.Palette(str(path))


# ---- Device ------------------------------------------------------------------

@pytest.mark.parametrize("percent, charging, level", [
    (80, False, "fine"),
    (36, False, "fine"),
    (35, False, "warning"),
    (21, False, "warning"),
    (20, False, "critical"),
    (5, False, "critical"),
    (5, True, "charging"),   # charging wins over a low percentage
    (90, True, "charging"),
])
def test_device_level(hub, percent, charging, level):
    assert hub.Device("Mouse", "m", percent, charging).level == level


def test_device_low_only_for_warning_and_critical(hub):
    assert hub.Device("a", "i", 30).low
    assert hub.Device("a", "i", 10).low
    assert not hub.Device("a", "i", 10, charging=True).low
    assert not hub.Device("a", "i", 90).low


def test_peripheral_label_gets_a_bolt_while_charging(hub):
    assert hub.Device("Mouse", "M", 45).label() == "M 45%"
    assert hub.Device("Mouse", "M", 45, charging=True).label() == f"{hub.CHARGING_ICON}M 45%"


def test_laptop_swaps_its_icon_instead_of_a_bolt(hub):
    charging = hub.Device.laptop(64, True)
    assert charging.is_laptop and charging.icon == hub.LAPTOP_CHARGING
    assert charging.label() == f"{hub.LAPTOP_CHARGING} 64%"
    assert hub.Device.laptop(64, False).icon == hub.LAPTOP_ICONS[6]
    assert hub.Device.laptop(100, False).icon == hub.LAPTOP_ICONS[10]


def test_tooltip_line_escapes_markup(hub):
    line = hub.Device("Pad <x> & co", "P", 15).tooltip_line()
    assert "Pad &lt;x&gt; &amp; co" in line


# ---- UPowerSource (adapter) --------------------------------------------------

def test_upower_mouse_becomes_a_device(hub):
    device = hub.UPowerSource.to_device(
        {"Type": 5, "Model": "MX Master 3S", "Percentage": 74.6, "State": 2, "IsPresent": True})
    assert device == hub.Device("MX Master 3S", hub.ICONS[5], 75, False)


def test_upower_system_battery_is_the_laptop(hub):
    device = hub.UPowerSource.to_device({"Type": 2, "PowerSupply": True, "Percentage": 64, "State": 1})
    assert device.is_laptop and device.charging and device.percent == 64


@pytest.mark.parametrize("state", [1, 4, 5])  # charging, fully charged, pending charge
def test_upower_states_on_the_charger(hub, state):
    assert hub.UPowerSource.to_device({"Type": 5, "Percentage": 50, "State": state}).charging


@pytest.mark.parametrize("props", [
    {"Type": 1},                                           # line power
    {"Type": 5, "Percentage": 40, "IsPresent": False},     # not present
    {"Type": 6, "Percentage": 0, "BatteryLevel": 1},       # no reading
])
def test_upower_ignores_what_is_not_a_readable_battery(hub, props):
    assert hub.UPowerSource.to_device(props) is None


def test_upower_unknown_type_gets_the_generic_icon(hub):
    device = hub.UPowerSource.to_device({"Type": 99, "Model": "Gadget", "Percentage": 50})
    assert device.icon == hub.OTHER_ICON


def test_upower_name_falls_back_to_native_path(hub):
    device = hub.UPowerSource.to_device({"Type": 5, "NativePath": "hid-00:11", "Percentage": 50})
    assert device.name == "hid-00:11"


# ---- HeadsetControlSource (adapter) ------------------------------------------

def test_headsetcontrol_json_becomes_devices(hub, monkeypatch):
    output = json.dumps({"devices": [
        {"product": "G733 Gaming Headset", "battery": {"level": 60, "status": "BATTERY_CHARGING"}},
        {"product": "Other", "battery": {"level": -1, "status": "BATTERY_UNAVAILABLE"}},
    ]})
    monkeypatch.setattr(hub.shutil, "which", lambda _: "/usr/bin/headsetcontrol")
    monkeypatch.setattr(hub.subprocess, "run",
                        lambda *a, **k: type("R", (), {"stdout": output})())
    devices = hub.HeadsetControlSource().read()
    assert devices == [hub.Device("G733 Gaming Headset", hub.ICONS[17], 60, True)]


def test_headsetcontrol_missing_or_broken_gives_nothing(hub, monkeypatch):
    monkeypatch.setattr(hub.shutil, "which", lambda _: None)
    assert hub.HeadsetControlSource().read() == []
    monkeypatch.setattr(hub.shutil, "which", lambda _: "/usr/bin/headsetcontrol")
    monkeypatch.setattr(hub.subprocess, "run", lambda *a, **k: type("R", (), {"stdout": "not json"})())
    assert hub.HeadsetControlSource().read() == []


# ---- Batteries ---------------------------------------------------------------

def test_batteries_merge_sort_and_split_the_laptop(hub):
    batteries = hub.Batteries([
        FakeSource([hub.Device("MX Keys", "k", 50), hub.Device("MX Keys Mini", "k", 40)]),
        FakeSource([hub.Device("G733 Gaming Headset", "h", 60), hub.Device.laptop(80, False)]),
    ])
    laptop, peripherals = batteries.collect()
    assert laptop.percent == 80
    assert [p.name for p in peripherals] == ["MX Keys Mini", "MX Keys", "G733 Gaming Headset"]


def test_batteries_drop_a_device_repeated_by_a_later_source(hub):
    _, peripherals = hub.Batteries([
        FakeSource([hub.Device("G733 Gaming Headset", "h", 60)]),
        FakeSource([hub.Device("G733", "h", 60)]),
    ]).collect()
    assert [p.name for p in peripherals] == ["G733 Gaming Headset"]


def test_batteries_keep_similar_names_from_one_source(hub):
    _, peripherals = hub.Batteries([
        FakeSource([hub.Device("MX Keys", "k", 50), hub.Device("MX Keys Mini", "k", 40)]),
    ]).collect()
    assert len(peripherals) == 2


# ---- Palette -----------------------------------------------------------------

def test_palette_reads_wallust_and_falls_back(hub, plain_palette, tmp_path):
    assert plain_palette.colour("critical") == "#ff0000"
    assert plain_palette.colour("fine") is None
    missing = hub.Palette(str(tmp_path / "nope.conf"))
    assert missing.colour("warning") == hub.Palette.LEVELS["warning"][1]


# ---- BatteryHub --------------------------------------------------------------

def devices(hub):
    return {
        "mouse": hub.Device("Mouse", "M", 80),
        "keys": hub.Device("Keys", "K", 30),          # warning
        "pad": hub.Device("Pad", "P", 15),            # critical
        "laptop": hub.Device.laptop(64, False),
    }


def test_desktop_compact_shows_the_lowest_peripheral(hub, plain_palette):
    d = devices(hub)
    view = hub.BatteryHub(None, [d["pad"], d["keys"], d["mouse"]], False, plain_palette).render()
    assert view["text"] == "P 15%"
    assert view["class"] == "critical"  # the stylesheet makes it blink


def test_laptop_compact_adds_a_low_peripheral_in_its_own_colour(hub, plain_palette):
    d = devices(hub)
    view = hub.BatteryHub(d["laptop"], [d["keys"], d["mouse"]], False, plain_palette).render()
    assert view["text"] == f"{d['laptop'].label()}  <span color='#ffaa00'>K 30%</span>"
    assert view["class"] == "fine"


def test_laptop_compact_alone_when_peripherals_are_fine(hub, plain_palette):
    d = devices(hub)
    view = hub.BatteryHub(d["laptop"], [d["mouse"]], False, plain_palette).render()
    assert view["text"] == d["laptop"].label()


def test_expanded_colours_each_device_by_its_own_level(hub, plain_palette):
    d = devices(hub)
    view = hub.BatteryHub(None, [d["pad"], d["keys"], d["mouse"]], True, plain_palette).render()
    assert view["text"] == ("<span color='#ff0000'>P 15%</span>  "
                            "<span color='#ffaa00'>K 30%</span>  M 80%")
    assert view["class"] == "expanded"


def test_tooltip_lists_everyone_and_percentage_is_the_lowest(hub, plain_palette):
    d = devices(hub)
    view = hub.BatteryHub(d["laptop"], [d["keys"], d["mouse"]], False, plain_palette).render()
    assert view["tooltip"].count("\n") == 2
    assert view["percentage"] == 30


def test_no_batteries_hides_the_module(hub, plain_palette):
    view = hub.BatteryHub(None, [], False, plain_palette).render()
    assert view["text"] == "" and view["tooltip"] == "No batteries"


# ---- LowBatteryNotifier --------------------------------------------------------

def test_notifies_once_per_level_and_again_after_a_recharge(hub, tmp_path, monkeypatch):
    sent = []
    monkeypatch.setattr(hub.subprocess, "run", lambda cmd, *a, **k: sent.append(cmd))
    notifier = hub.LowBatteryNotifier(state=str(tmp_path / "notified.json"),
                                      hook=str(tmp_path / "no-hook"))
    for percent, charging in [(50, False), (33, False), (31, False), (18, False),
                              (15, False), (15, True), (60, False), (30, False)]:
        notifier.notify([hub.Device("Pad", "P", percent, charging)])
    urgencies = [cmd[cmd.index("-u") + 1] for cmd in sent]
    assert urgencies == ["normal", "critical", "normal"]


def test_hook_gets_name_percent_and_level(hub, tmp_path, monkeypatch):
    monkeypatch.setattr(hub.subprocess, "run", lambda *a, **k: None)
    log = tmp_path / "hook.log"
    hook = tmp_path / "battery-hook"
    hook.write_text(f'#!/bin/sh\necho "$1|$2|$3" > {log}\n')
    hook.chmod(0o755)
    notifier = hub.LowBatteryNotifier(state=str(tmp_path / "notified.json"), hook=str(hook))
    notifier.notify([hub.Device("Pad", "P", 18)])
    for _ in range(50):  # the hook runs detached
        if log.exists():
            break
        time.sleep(0.05)
    assert log.read_text().strip() == "Pad|18|critical"


# ---- ViewState -----------------------------------------------------------------

def test_view_toggles_and_tells_the_running_module(hub, tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(hub.subprocess, "run", lambda cmd, *a, **k: calls.append(cmd))
    view = hub.ViewState(str(tmp_path / "expanded"))
    assert not view.expanded
    view.toggle()
    assert view.expanded
    view.toggle()
    assert not view.expanded
    assert calls == [["pkill", "-USR1", "-f", r"battery-hub\.py$"]] * 2


def test_toggle_pattern_spares_the_toggle_run_itself(hub):
    import re
    pattern = r"battery-hub\.py$"
    assert re.search(pattern, "python3 /home/u/.local/bin/battery-hub.py")
    assert not re.search(pattern, "python3 /home/u/.local/bin/battery-hub.py --toggle")


# ---- BatteryHubModule --------------------------------------------------------

def test_module_state_reads_notifies_and_renders(hub, tmp_path, monkeypatch):
    sent = []
    monkeypatch.setattr(hub.subprocess, "run", lambda cmd, *a, **k: sent.append(cmd))
    monkeypatch.setattr(hub, "ViewState", lambda: type("V", (), {"expanded": False})())
    module = hub.BatteryHubModule(sources=[FakeSource([hub.Device("Pad", "P", 15)])])
    module.notifier = hub.LowBatteryNotifier(state=str(tmp_path / "n.json"),
                                             hook=str(tmp_path / "no-hook"))
    state = module.state()
    assert state["text"] == "P 15%" and state["class"] == "critical"
    assert sent and sent[0][0] == "notify-send"
