#!/usr/bin/env python3
"""Every battery in one Waybar module.

Asks UPower for all devices with a battery (laptop, mice, keyboards,
trackpads, controllers, Bluetooth headsets, phones...) instead of matching
model names, and adds what UPower cannot see: USB headsets through
headsetcontrol (the Logitech G733, say), when it is installed, and devices
behind a Logitech Bolt receiver, which the kernel has no driver for, by
asking the receiver itself over HID++.

Two views, switched by clicking the module (--toggle):
  compact   the laptop battery, or on a desktop the lowest peripheral; a
            laptop also shows a peripheral that runs low, so it is not missed
  expanded  every battery, laptop first, lowest peripheral next
The tooltip always lists every device by name. With no battery at all the
text is empty and Waybar hides the module.

Low batteries are announced once per level (warning, then critical) with a
desktop notification, again after a recharge. For anything personal on top
(a Telegram message, say), make ~/.config/hyprflow/battery-hook executable:
it runs with the device name, the percentage and the level. It lives outside
the repo.

    battery-hub.py            the module (Waybar exec, continuous: no interval)
    battery-hub.py --toggle   switch view; the running module redraws (on-click)
    battery-hub.py --lights   headset lights on/off via headsetcontrol (on-click-right)

It updates on events (Observer): UPower signals a device added, removed or
changed, and the module redraws at once instead of Waybar polling it every
minute. Only headsetcontrol and the Bolt receiver, which have no events, are
polled, and only when present.

Layout: Device is the model; UPowerSource, HeadsetControlSource and
HidppSource are adapters that turn each source's format into Devices (add a source by writing
another class with read()); Batteries gathers them; BatteryHub presents them;
BatteryHubModule plugs it all into hyprflow.waybar.
"""

import json
import os
import select
import shutil
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Protocol

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib, GLibUnix  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import notify, palette, paths  # noqa: E402
from hyprflow.waybar import WaybarModule  # noqa: E402

HEADSET_POLL = 60  # seconds; headsetcontrol reports no events
HIDPP_POLL = 300   # seconds; batteries behind a Logitech receiver last weeks
BLE_POLL = 600     # seconds between Bluetooth LE scans, while AirPods are connected
BLE_SCAN = 6       # seconds a scan lasts; it shares the radio with the audio
BLE_STALE = 1800   # seconds; an older AirPods reading is dropped
EXPANDED = str(paths.HYPRFLOW_RUNTIME / "battery-hub-expanded")
NOTIFIED = str(paths.HYPRFLOW_RUNTIME / "battery-hub-notified.json")
# headsetcontrol can set the headset lights but not read them back, so the
# last value sent is kept here (survives reboots, like the headset itself).
LIGHTS = str(paths.HYPRFLOW_STATE / "headset-lights")
HOOK = str(paths.HYPRFLOW_CONFIG / "battery-hook")
PALETTE = palette.FILE
WARNING = 35   # percent; same thresholds the old per-device modules used
CRITICAL = 20

UPOWER = "org.freedesktop.UPower"
BLUEZ = "org.bluez"
APPLE = 0x004C  # Bluetooth company id
DBUS_TIMEOUT_MS = 2000  # a stuck UPower must not hold the bar for D-Bus's default 25 s
# UPower device types (UpDeviceKind).
LINE_POWER, BATTERY = 1, 2
ICONS = {
    5: "󰍽",   # mouse
    6: "󰌌",   # keyboard
    8: "󰏲",   # phone
    10: "󰓶",  # tablet
    12: "󰊴",  # gaming input (controllers)
    13: "󰏪",  # pen
    14: "󰟸",  # touchpad
    17: "󰋋",  # headset
    19: "󰋋",  # headphones
}
OTHER_ICON = "󰂎"
CHARGING_ICON = "󱐋"
LAPTOP_ICONS = "󰂎󰁺󰁻󰁼󰁽󰁾󰁿󰂀󰂁󰂂󰁹"  # 0 %, 10 % ... 100 %
LAPTOP_CHARGING = "󰂄"
# UPower states that mean "on the charger".
CHARGING, FULLY_CHARGED, PENDING_CHARGE = 1, 4, 5


@dataclass
class Device:
    """A battery: a peripheral, or the laptop itself (is_laptop)."""
    name: str
    icon: str
    percent: int
    charging: bool = False
    is_laptop: bool = False

    @classmethod
    def laptop(cls, percent, charging):
        icon = LAPTOP_CHARGING if charging else LAPTOP_ICONS[max(0, min(percent // 10, 10))]
        return cls("Laptop", icon, percent, charging, is_laptop=True)

    @property
    def level(self):
        """charging, critical, warning or fine; charging wins over the rest."""
        if self.charging:
            return "charging"
        if self.percent <= CRITICAL:
            return "critical"
        if self.percent <= WARNING:
            return "warning"
        return "fine"

    @property
    def low(self):
        return self.level in ("warning", "critical")

    def label(self):
        """Bar text. A peripheral gets a bolt while charging, as the old per
        device modules showed it; the laptop swaps its icon instead."""
        bolt = CHARGING_ICON if self.charging and not self.is_laptop else ""
        return f"{bolt}{self.icon} {self.percent}%"

    def tooltip_line(self):
        bolt = f"  {CHARGING_ICON}" if self.charging and not self.is_laptop else ""
        return f"{self.icon}  {GLib.markup_escape_text(self.name)}  {self.percent}%{bolt}"


class BatterySource(Protocol):
    """A place batteries come from. Each adapter turns its own format into
    Devices; nothing past this point knows where a device was read."""

    def read(self) -> list[Device]: ...

    def watch(self, changed) -> None:
        """Calls changed() whenever the batteries may have changed (Observer);
        each source knows its own events, the module does not. Optional: a
        source without events is simply read on every redraw."""


class UPowerSource:
    """Adapter for UPower (D-Bus): the laptop and every peripheral the kernel
    reports a battery for."""

    def read(self):
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
        paths = bus.call_sync(UPOWER, "/org/freedesktop/UPower", UPOWER, "EnumerateDevices",
                              None, GLib.VariantType("(ao)"), Gio.DBusCallFlags.NONE, DBUS_TIMEOUT_MS, None)
        devices = []
        for path in paths.unpack()[0]:
            props = bus.call_sync(UPOWER, path, "org.freedesktop.DBus.Properties", "GetAll",
                                  GLib.Variant("(s)", (f"{UPOWER}.Device",)),
                                  GLib.VariantType("(a{sv})"), Gio.DBusCallFlags.NONE, DBUS_TIMEOUT_MS, None)
            device = self.to_device(props.unpack()[0])
            if device:
                devices.append(device)
        return devices

    def watch(self, changed):
        # Every UPower signal: DeviceAdded/DeviceRemoved on the daemon and
        # PropertiesChanged on each device (percentage, charging...).
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
        bus.signal_subscribe(UPOWER, None, None, None, None, Gio.DBusSignalFlags.NONE, changed)

    @staticmethod
    def to_device(props):
        """One UPower property set as a Device, or None when it is not a
        battery worth showing."""
        kind = props.get("Type", 0)
        if kind == LINE_POWER or not props.get("IsPresent", True):
            return None
        charging = props.get("State") in (CHARGING, FULLY_CHARGED, PENDING_CHARGE)
        percent = round(props.get("Percentage", 0))
        if kind == BATTERY and props.get("PowerSupply"):
            return Device.laptop(percent, charging)
        # BatteryLevel 1 = none reported: a device with a battery UPower
        # cannot read, which shows as 0 %.
        if percent <= 0 and props.get("BatteryLevel", 0) == 1:
            return None
        name = props.get("Model") or props.get("NativePath") or "Device"
        return Device(name, ICONS.get(kind, OTHER_ICON), percent, charging)


class HeadsetControlSource:
    """Adapter for headsetcontrol (JSON): USB headsets whose battery the
    kernel, and so UPower, never sees."""

    def read(self):
        if not shutil.which("headsetcontrol"):
            return []
        try:
            out = subprocess.run(["headsetcontrol", "-b", "-o", "json"],
                                 capture_output=True, text=True, timeout=5).stdout
            data = json.loads(out)
        except (subprocess.SubprocessError, ValueError):
            return []
        # Its JSON as documented, or nothing: an old or odd version must not
        # take the whole module down.
        headsets = data.get("devices") if isinstance(data, dict) else None
        devices = []
        for headset in headsets if isinstance(headsets, list) else []:
            battery = headset.get("battery") if isinstance(headset, dict) else None
            level = battery.get("level") if isinstance(battery, dict) else None
            if not isinstance(level, int) or level < 0:  # off, out of range, or unknown
                continue
            devices.append(Device(headset.get("product", "Headset"), ICONS[17], level,
                                  battery.get("status") == "BATTERY_CHARGING"))
        return devices

    def watch(self, changed):
        # headsetcontrol has no events: poll, and only when it is installed.
        if shutil.which("headsetcontrol"):
            GLib.timeout_add_seconds(HEADSET_POLL, changed)


class AppleBleSource:
    """Adapter for the battery AirPods broadcast over Bluetooth LE for nearby
    iPhones (Apple's proximity message, the card an iPhone shows). AirPods Max
    report it nowhere else: not to BlueZ, so not to UPower. Any AirPods nearby
    broadcast too, so a model is shown only while a pair of it is connected
    here. In steps of 10 %."""

    MODELS = {0x201F: "AirPods Max", 0x200A: "AirPods Max"}  # model id -> name

    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.readings = {}  # model id -> (percent, when)
        self.changed = None

    @staticmethod
    def parse(data):
        """(model id, percent) from a proximity message, or None. The level is
        a nibble, 0-10 in tens; 15 means unknown."""
        if len(data) < 8 or data[0] != 0x07:
            return None
        level = data[6] & 0x0F
        if level > 10:
            return None
        return data[3] | data[4] << 8, level * 10

    def devices(self):
        """BlueZ's known devices: {path: Device1 properties}."""
        try:
            bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
            objects = bus.call_sync(BLUEZ, "/", "org.freedesktop.DBus.ObjectManager",
                                    "GetManagedObjects", None, None, Gio.DBusCallFlags.NONE,
                                    DBUS_TIMEOUT_MS, None).unpack()[0]
        except GLib.Error:
            return {}
        return {path: ifaces["org.bluez.Device1"] for path, ifaces in objects.items()
                if "org.bluez.Device1" in ifaces}

    def connected_models(self):
        """Model ids of the Apple devices connected to this computer, from
        their Modalias (bluetooth:v004Cp201F...)."""
        models = set()
        for device in self.devices().values():
            modalias = device.get("Modalias", "")
            if device.get("Connected") and modalias.startswith("bluetooth:v004Cp"):
                models.add(int(modalias[16:20], 16))
        return models

    def read(self):
        now, devices = self.clock(), []
        for model in self.connected_models() & self.MODELS.keys():
            reading = self.readings.get(model)
            if reading and now - reading[1] < BLE_STALE:
                devices.append(Device(self.MODELS[model], ICONS[19], reading[0]))
        return devices

    def heard(self, data):
        """One advert: keep the reading if it is a model we know."""
        found = self.parse(bytes(data))
        if found and found[0] in self.MODELS:
            model, percent = found
            new = self.readings.get(model, (None,))[0] != percent
            self.readings[model] = (percent, self.clock())
            if new and self.changed:
                self.changed()

    def collect(self):
        """The adverts BlueZ holds after a scan. Read from its device list, not
        from change signals: an advert already known sends none."""
        for device in self.devices().values():
            data = device.get("ManufacturerData", {}).get(APPLE)
            if data:
                self.heard(data)

    def watch(self, changed):
        self.changed = changed
        GLib.timeout_add_seconds(3, lambda: self.scan() and False)  # once, soon after start
        GLib.timeout_add_seconds(BLE_POLL, self.scan)                # then now and then

    def scan(self):
        """A short LE scan, only while AirPods are connected: it shares the
        radio with their audio. A GLib callback; True keeps the poll going."""
        if not self.connected_models() & self.MODELS.keys():
            return True
        # Not while gaming: a scan loads the radio the controller is on, and a
        # cheap adapter can stall under it.
        if (paths.HYPRFLOW_STATE / "game-mode").exists():
            return True
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
        adapter = "/org/bluez/hci0"
        try:
            bus.call_sync(BLUEZ, adapter, "org.bluez.Adapter1", "SetDiscoveryFilter",
                          GLib.Variant("(a{sv})", ({"Transport": GLib.Variant("s", "le"),
                                                    "DuplicateData": GLib.Variant("b", True)},)),
                          None, Gio.DBusCallFlags.NONE, DBUS_TIMEOUT_MS, None)
            bus.call_sync(BLUEZ, adapter, "org.bluez.Adapter1", "StartDiscovery",
                          None, None, Gio.DBusCallFlags.NONE, DBUS_TIMEOUT_MS, None)
        except GLib.Error:
            return True

        def finish():
            self.collect()
            try:
                bus.call_sync(BLUEZ, adapter, "org.bluez.Adapter1", "StopDiscovery",
                              None, None, Gio.DBusCallFlags.NONE, DBUS_TIMEOUT_MS, None)
            except GLib.Error:
                pass
            return False

        GLib.timeout_add_seconds(BLE_SCAN, finish)
        return True


class HidrawTransport:
    """HID++ requests to a Logitech receiver through its hidraw node. A
    request is a short report; the answer is matched by device, feature and
    a software id, skipping the notifications the receiver sends unasked."""

    SWID = 0x0A
    # Seconds. An awake device answers in milliseconds; a sleeping one needs
    # this long to wake up; an empty slot never answers.
    TIMEOUT = 1.0

    def __init__(self, fd):
        self.fd = fd

    def request(self, device, feature, function, *params):
        """The answer's parameters, or None for an error or no answer (an
        empty slot, a device switched off or asleep)."""
        call = (function << 4) | self.SWID
        os.write(self.fd, bytes([0x10, device, feature, call, *params, 0, 0, 0][:7]))
        deadline = time.monotonic() + self.TIMEOUT
        while (left := deadline - time.monotonic()) > 0:
            if not select.select([self.fd], [], [], left)[0]:
                return None
            reply = os.read(self.fd, 20)
            if len(reply) < 4 or reply[1] != device:
                continue
            if reply[2] == 0x8F or (reply[2] == 0xFF and reply[3] == feature):  # HID++ 1.0 / 2.0 error
                return None
            if reply[2] == feature and reply[3] == call:
                return reply[4:]
        return None


class HidppSource:
    """Adapter for devices paired to a Logitech Bolt receiver. The kernel's
    hid-logitech-dj does not know the Bolt, so no battery reaches UPower;
    the receiver still answers HID++ 2.0, and devices report a percentage
    through their UNIFIED_BATTERY feature (or the older BATTERY_STATUS).

    Reading /dev/hidrawN needs the udev rule in system/ (see the README).
    The receiver is asked at most every HIDPP_POLL seconds; in between the
    last reading is returned, since the module redraws on every UPower event."""

    RECEIVERS = {"0000C548"}                  # Logi Bolt
    ROOT, DEVICE_NAME, BATTERY_STATUS, UNIFIED_BATTERY = 0x0000, 0x0005, 0x1000, 0x1004
    SLOTS = range(1, 7)
    KIND_ICONS = {0: ICONS[6], 3: ICONS[5], 4: ICONS[14], 5: ICONS[5]}  # keyboard, mouse, trackpad, trackball
    LEVEL_PERCENT = ((8, 100), (4, 50), (2, 20), (1, 5))                # full, good, low, critical

    CONNECT_DELAY = 5  # seconds; a device reports a stand-in charge right after connecting
    CHANGE_DELAY = 1
    CONFIRM_DELAY = 5  # seconds before reading again a reading not trusted yet
    SLOW = 0.2         # seconds; an awake device answers in tens of milliseconds
    DROP = 20          # points; a real battery does not lose this many between polls
    BUDGET = 3.0       # seconds for a whole sweep; sleeping devices can take one each
    REWATCH = 5        # seconds between looks for a receiver that is not plugged in

    def __init__(self, sysfs="/sys/class/hidraw", clock=time.monotonic):
        self.sysfs = Path(sysfs)
        self.clock = clock
        self.cache, self.read_at = [], None
        self.last = {}     # slot -> Device, for a paired device that dozes off
        self.suspect = {}  # slot -> percent read once but not trusted yet
        self.recheck = False
        self.changed = None

    def node(self):
        """The receiver's HID++ interface: the hidraw whose report
        descriptor opens with the vendor usage page 0xFF00."""
        for entry in sorted(self.sysfs.glob("hidraw*")):
            try:
                uevent = (entry / "device" / "uevent").read_text()
                descriptor = (entry / "device" / "report_descriptor").read_bytes()
            except OSError:
                continue
            product = next((line.split(":")[-1] for line in uevent.splitlines()
                            if line.startswith("HID_ID=")), "")
            if product in self.RECEIVERS and descriptor.startswith(b"\x06\x00\xff"):
                return Path("/dev") / entry.name
        return None

    @staticmethod
    def refresh_delay(report):
        """Seconds to wait before reading again, for a report the receiver
        sent unasked; None for anything else. Answers to our own requests
        carry a software id and are ignored, or they would loop."""
        if len(report) < 4 or report[0] not in (0x10, 0x11) or report[2] in (0x8F, 0xFF):
            return None
        if report[2] in (0x40, 0x41):               # device disconnected / connected
            return HidppSource.CONNECT_DELAY
        if report[2] < 0x40 and report[3] & 0x0F == 0:  # a feature's own event (battery...)
            return HidppSource.CHANGE_DELAY
        return None

    def invalidate(self):
        """The next read asks the receiver instead of returning the cache."""
        self.read_at = None

    def read(self):
        if self.read_at is not None and self.clock() - self.read_at < HIDPP_POLL:
            return self.cache
        node = self.node()
        if node is None or not os.access(node, os.R_OK | os.W_OK):
            return []
        try:
            fd = os.open(node, os.O_RDWR)
        except OSError:
            return []
        try:
            self.cache = self.devices(HidrawTransport(fd))
        except OSError:
            self.cache = []
        finally:
            os.close(fd)
        self.read_at = self.clock()
        if self.recheck and self.changed:
            GLib.timeout_add_seconds(self.CONFIRM_DELAY, self.refresh)
        return self.cache

    def refresh(self, *_):
        """Read the receiver again now: a one shot GLib callback."""
        self.invalidate()
        if self.changed:
            self.changed()
        return False

    def watch(self, changed):
        """The receiver's own reports as events: a device connecting or a
        battery changing triggers a read a moment later. Polled every
        HIDPP_POLL seconds as a fallback."""
        self.changed = changed
        GLib.timeout_add_seconds(HIDPP_POLL, changed)
        if self.recheck:  # the first read, done before this, held one back
            GLib.timeout_add_seconds(self.CONFIRM_DELAY, self.refresh)
        self.listen()

    def listen(self):
        """Watches the receiver's reports. Without a receiver (not plugged in
        yet, or just unplugged) it looks again every REWATCH seconds, so a
        replugged one is heard again, not only at the next poll."""
        node = self.node()
        try:
            fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK) if node else None
        except OSError:
            fd = None
        if fd is None:
            GLib.timeout_add_seconds(self.REWATCH, self.relisten)
            return False

        def on_report(*_):
            try:
                report = os.read(fd, 20)
            except BlockingIOError:
                return True
            except OSError:  # receiver unplugged: let go of it, then look again
                os.close(fd)
                self.refresh()
                GLib.timeout_add_seconds(self.REWATCH, self.relisten)
                return False
            delay = self.refresh_delay(report)
            if delay is not None:
                GLib.timeout_add_seconds(delay, self.refresh)
            return True

        GLib.io_add_watch(GLib.IOChannel.unix_new(fd), GLib.PRIORITY_DEFAULT,
                          GLib.IOCondition.IN | GLib.IOCondition.HUP, on_report)
        return True

    def relisten(self):
        """A one shot GLib callback: listen again, and read the receiver at
        once when it is back."""
        if self.listen():
            self.refresh()
        return False

    def devices(self, hidpp):
        """Every paired device. One that is paired but does not answer this
        time (asleep, or waking up too slowly) keeps its last reading instead
        of dropping out of the bar."""
        found = []
        self.recheck = False
        deadline = self.clock() + self.BUDGET
        for slot in self.SLOTS:
            if self.clock() > deadline:
                # Out of time: the rest keep their last reading, and are read
                # again shortly instead of blocking the bar any longer.
                found += [self.last[s] for s in self.SLOTS if s >= slot and s in self.last]
                self.recheck = True
                break
            started = self.clock()
            battery = self.battery(hidpp, slot)
            slow = self.clock() - started > self.SLOW
            if battery is None:
                if slot in self.last and self.paired(hidpp, slot):
                    found.append(self.last[slot])
                continue
            if not self.trusted(slot, *battery, slow):
                self.recheck = True
                if slot in self.last:
                    found.append(self.last[slot])
                continue
            name, kind = self.identity(hidpp, slot)
            self.last[slot] = Device(name, self.KIND_ICONS.get(kind, OTHER_ICON), *battery)
            found.append(self.last[slot])
        return found

    def trusted(self, slot, percent, charging, slow):
        """Whether a reading can be shown. Not yet when the device answered
        slowly (it was asleep, and a device that just woke can report a stand
        in charge) or when it fell sharply without charging: such a reading
        is held back and read again a moment later, and it is only taken
        when it repeats."""
        last = self.last.get(slot)
        dropped = last is not None and not charging and last.percent - percent > self.DROP
        if not (slow or dropped):
            self.suspect.pop(slot, None)
            return True
        repeated = self.suspect.get(slot) is not None and abs(self.suspect[slot] - percent) <= 2
        if repeated and not slow:
            self.suspect.pop(slot, None)
            return True
        self.suspect[slot] = percent
        return False

    def paired(self, hidpp, slot):
        """The receiver still answers for the slot: a device is paired there."""
        return self.feature(hidpp, slot, self.UNIFIED_BATTERY) is not None \
            or self.feature(hidpp, slot, self.BATTERY_STATUS) is not None

    def feature(self, hidpp, slot, feature_id):
        """The index a device gives a feature, or None without it."""
        answer = hidpp.request(slot, self.ROOT, 0, feature_id >> 8, feature_id & 0xFF)
        return answer[0] if answer and answer[0] else None

    def battery(self, hidpp, slot):
        """(percent, charging), or None when the slot is empty or asleep."""
        index = self.feature(hidpp, slot, self.UNIFIED_BATTERY)
        if index is not None:
            status = hidpp.request(slot, index, 1)
            if status is None:
                return None
            percent, levels, charging = status[0], status[1], status[2]
            if percent > 100:  # 0xFF: disabled or unknown, not a 255 % battery
                return None
            if not percent:  # a device that only reports coarse levels
                percent = next((p for bit, p in self.LEVEL_PERCENT if levels & bit), 0)
            return percent, charging in (1, 2, 3)
        index = self.feature(hidpp, slot, self.BATTERY_STATUS)
        if index is not None:
            status = hidpp.request(slot, index, 0)
            if status is not None and status[0] <= 100:  # 0xFF: unknown
                return status[0], status[2] in (1, 2, 3)
        return None

    def identity(self, hidpp, slot):
        """(name, kind) from the DEVICE_NAME feature; kind 0 is a keyboard,
        3 a mouse. A device without it is just "Logitech device"."""
        index = self.feature(hidpp, slot, self.DEVICE_NAME)
        if index is None:
            return "Logitech device", None
        length = (hidpp.request(slot, index, 0) or [0])[0]
        name = b""
        while len(name) < length:
            chunk = hidpp.request(slot, index, 1, len(name))
            if not chunk:
                break
            name += bytes(chunk[: length - len(name)])
        kind = hidpp.request(slot, index, 2)
        return name.decode(errors="replace").strip("\0 ") or "Logitech device", kind[0] if kind else None


class Batteries:
    """Every source put together: one laptop at most, and the peripherals,
    lowest first, each listed once even if two sources report it."""

    def __init__(self, sources: list[BatterySource]):
        self.sources = sources

    def collect(self):
        laptop, peripherals = None, []
        for source in self.sources:
            earlier = list(peripherals)  # only other sources can repeat a device
            for device in source.read():
                if device.is_laptop:
                    laptop = device
                elif not self.seen(device, earlier):
                    peripherals.append(device)
        peripherals.sort(key=lambda d: d.percent)
        return laptop, peripherals

    @staticmethod
    def seen(device, devices):
        """A headset UPower also reports over Bluetooth shows up in both
        sources under slightly different names ("G733" / "G733 Gaming
        Headset"). Devices within one source are all distinct."""
        name = device.name.lower()
        return any(name in d.name.lower() or d.name.lower() in name for d in devices)


class Palette:
    """Per device colours inside the module: wallust's palette when there is
    one, else the Tokyo Night shades the minor style uses."""

    LEVELS = {"warning": ("color3", "#e0af68"), "critical": ("color1", "#f7768e"),
              "charging": ("color6", "#9ece6a")}

    def __init__(self, path=PALETTE):
        self.colours = palette.load(path)

    def colour(self, level):
        """The colour for a level, or None for fine (left to the stylesheet)."""
        if level not in self.LEVELS:
            return None
        key, fallback = self.LEVELS[level]
        return self.colours.get(key, fallback)


class BatteryHub:
    """Turns the batteries into the Waybar module for the current view."""

    def __init__(self, laptop, peripherals, expanded, palette):
        self.laptop = laptop
        self.peripherals = peripherals
        self.expanded = expanded
        self.palette = palette

    def shown(self):
        """Devices in the bar text, in order."""
        head = [self.laptop] if self.laptop else []
        if self.expanded:
            return head + self.peripherals
        if not self.laptop:
            return self.peripherals[:1]  # desktop: the lowest one stands for the rest
        if self.peripherals and self.peripherals[0].low:
            return head + self.peripherals[:1]
        return head

    def paint(self, device):
        colour = self.palette.colour(device.level)
        return f"<span color='{colour}'>{device.label()}</span>" if colour else device.label()

    def render(self):
        """The module JSON. Each device keeps its own colour, as the separate
        modules used to. In the compact view the first one styles the whole
        module (so critical still blinks through CSS); anything else, and
        every device in the full view, is coloured inline."""
        shown = self.shown()
        if self.expanded or not shown:
            module_class = "expanded" if shown else "fine"
            text = "  ".join(self.paint(d) for d in shown)
        else:
            module_class = shown[0].level
            text = "  ".join([shown[0].label()] + [self.paint(d) for d in shown[1:]])
        everyone = ([self.laptop] if self.laptop else []) + self.peripherals
        return {
            "text": text,
            "tooltip": "\n".join(d.tooltip_line() for d in everyone) or "No batteries",
            "class": module_class,
            "percentage": min((p.percent for p in self.peripherals),
                              default=self.laptop.percent if self.laptop else 100),
        }


class LowBatteryNotifier:
    """Announces each device once per level it drops into.

    The last level announced per device is kept in a runtime file, so it
    starts fresh every boot. Charging or back above the warning level clears
    it, and the next drop is announced again.
    """

    SEVERITY = {"warning": 1, "critical": 2}

    def __init__(self, state=NOTIFIED, hook=HOOK):
        self.state = state
        self.hook = hook

    def notify(self, devices):
        notified = self.load()
        for d in devices:
            if d.level not in self.SEVERITY:
                notified.pop(d.name, None)
                continue
            if self.SEVERITY[d.level] <= self.SEVERITY.get(notified.get(d.name), 0):
                continue
            notified[d.name] = d.level
            self.announce(d)
        self.save(notified)

    def announce(self, d):
        urgency = "critical" if d.level == "critical" else "normal"
        notify.send(f"{d.name}: {d.percent}%",
                    "Almost empty, charge it soon." if d.level == "critical" else "Running low.",
                    app="Battery", urgency=urgency, icon="battery-low")
        if os.access(self.hook, os.X_OK):
            subprocess.Popen([self.hook, d.name, str(d.percent), d.level],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)

    def load(self):
        try:
            with open(self.state) as f:
                return json.load(f)
        except (OSError, ValueError):
            return {}

    def save(self, notified):
        try:
            with open(self.state, "w") as f:
                json.dump(notified, f)
        except OSError:
            pass


class HeadsetLights:
    """The headset lights (the G733's RGB, say), on or off."""

    def __init__(self, state=LIGHTS):
        self.state = state

    def toggle(self):
        if not shutil.which("headsetcontrol"):
            return
        try:
            with open(self.state) as f:
                on = f.read().strip() != "off"
        except OSError:
            on = True  # headsets ship with their lights on
        new = "off" if on else "on"
        result = subprocess.run(["headsetcontrol", "-l", "0" if new == "off" else "1"],
                                capture_output=True)
        if result.returncode == 0:
            os.makedirs(os.path.dirname(self.state), exist_ok=True)
            with open(self.state, "w") as f:
                f.write(new)


class ViewState:
    """Compact or expanded, kept in a runtime file shared with Waybar's runs."""

    def __init__(self, path=EXPANDED):
        self.path = path

    @property
    def expanded(self):
        return os.path.exists(self.path)

    def toggle(self):
        """Flips the view and tells the running module to redraw (SIGUSR1).
        The pattern matches the module, not this --toggle run."""
        if self.expanded:
            os.remove(self.path)
        else:
            open(self.path, "w").close()
        subprocess.run(["pkill", "-USR1", "-f", r"battery-hub\.py$"])


def default_sources():
    """A fresh set: sources keep state (caches, a receiver's fd)."""
    return [UPowerSource(), HeadsetControlSource(), HidppSource(), AppleBleSource()]


class BatteryHubModule(WaybarModule):
    """The Waybar module: redraws whenever a source says something changed
    (Observer: each source watches its own events) and when the view is
    toggled."""

    def __init__(self, sources: list[BatterySource] | None = None):
        super().__init__()
        self.sources = default_sources() if sources is None else list(sources)
        self._changed = None  # set once the sources watch; see events()
        self.notifier = LowBatteryNotifier()

    def state(self):
        laptop, peripherals = Batteries(self.sources).collect()
        self.notifier.notify(([laptop] if laptop else []) + peripherals)
        return BatteryHub(laptop, peripherals, ViewState().expanded, Palette()).render()

    def events(self):
        # run() calls this again after an error. The watches live in GLib's
        # loop, not here, so they are set up once; a second set would pile up.
        if self._changed is None:
            self._changed = changed = []

            def mark(*_):
                changed.append(True)
                return True  # keep GLib timers and signal handlers installed

            for source in self.sources:
                watch = getattr(source, "watch", None)
                if watch:
                    watch(mark)
            GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, mark)  # --toggle
        changed = self._changed
        context = GLib.MainContext.default()
        while True:
            context.iteration(True)
            if changed:
                changed.clear()
                yield


def main():
    if "--toggle" in sys.argv:
        ViewState().toggle()
        return
    if "--lights" in sys.argv:
        HeadsetLights().toggle()
        return
    BatteryHubModule().run()


if __name__ == "__main__":
    main()
