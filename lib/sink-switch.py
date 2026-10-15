#!/usr/bin/env python3
"""Audio output switcher: the Waybar volume click and Super+K's "Audio output".

Replaces the sinkswitch submodule: a port of Seyloria's sinkswitch
(https://github.com/Seyloria/sinkswitch, GPL-3.0) to Python and Quickshell.
Lists the PipeWire sinks, drops the ones the personal config hides, makes the
chosen one the default and can move the running streams to it.

The config lives outside the repo, so it is per machine and never committed:

    ~/.config/hyprflow/sink-switch.conf

One pattern per line hides every sink it matches; a pattern is a substring
(case-insensitive) of the node name, description or nickname. Not the id:
PipeWire hands out new ones on every boot. '#' starts a comment, blank lines
are ignored.

    # the HDMI output of the TV, never wanted
    HDMI
    # the G733 dongle
    G733

    sink-switch.py            the rofi menu, then switch
    sink-switch.py --toggle   the Quickshell panel, or the rofi menu
    sink-switch.py --json     the list for the panel ([{id, label, default, kind, icon}])
    sink-switch.py --set ID   make ID the default (and move the streams)
    sink-switch.py --no-sync  do not move the running streams
"""

import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import osd, paths  # noqa: E402
from hyprflow.menu import RofiMenu  # noqa: E402

CONFIG = str(paths.HYPRFLOW_CONFIG / "sink-switch.conf")
SPEAKER = "\U000f057e"  # volume high; the generic audio glyph, from Osd.qml
# Nerd Font (Material Design) glyphs, one per device family. The panel rows and
# the OSD both draw the chosen sink with its own; the family comes from kind_of.
ICONS = {
    "speaker": "\U000f04c3",    # md-speaker
    "headset": "\U000f02ce",    # md-headset
    "monitor": "\U000f0502",    # md-television
    "bluetooth": "\U000f00b0",  # md-bluetooth-audio
}
TIMEOUT = 5  # seconds; a stuck wpctl/pactl must not hang the panel


@dataclass
class Sink:
    id: int
    name: str          # node.name, stable across reboots
    description: str
    nick: str
    default: bool = False
    kind: str = "speaker"  # the icon family: speaker, headset, monitor, bluetooth

    @property
    def label(self):
        """What the menu shows: the short nickname, else the description."""
        return self.nick or self.description or self.name

    @property
    def icon(self):
        """The glyph for its family; the generic speaker as the fallback."""
        return ICONS.get(self.kind, SPEAKER)


def kind_of(props):
    """The icon family of a sink, guessed from its PipeWire properties."""
    bus = props.get("device.bus", "").lower()
    form = props.get("device.form-factor", "").lower()
    name = props.get("node.name", "").lower()
    profile = props.get("device.profile.name", "").lower()
    text = " ".join((name, props.get("node.description", "").lower(),
                     props.get("node.nick", "").lower()))
    if bus == "bluetooth" or name.startswith("bluez"):
        return "bluetooth"
    if form in ("headset", "headphones", "earbud", "earbuds") or \
            any(word in text for word in ("headset", "headphone", "earbud")):
        return "headset"
    if "hdmi" in profile or "displayport" in profile or \
            "hdmi" in name or "displayport" in name:
        return "monitor"
    return "speaker"


def out(argv):
    """stdout of a command, or "" when it is missing or fails."""
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout


def default_name():
    """The node name of the default sink, or ""."""
    found = re.search(r'node\.name\s*=\s*"([^"]*)"',
                      out(["wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"]))
    return found.group(1) if found else ""


def sinks():
    """Every PipeWire sink, default flagged. [] when pw-dump is missing."""
    try:
        dump = json.loads(out(["pw-dump"]) or "[]")
    except json.JSONDecodeError:
        return []
    default = default_name()
    found = []
    for node in dump:
        if node.get("type") != "PipeWire:Interface:Node":
            continue
        props = node.get("info", {}).get("props", {})
        if props.get("media.class") != "Audio/Sink":
            continue
        name = props.get("node.name", "")
        found.append(Sink(
            id=node["id"], name=name,
            description=props.get("node.description", ""),
            nick=props.get("node.nick", ""),
            default=name == default,
            kind=kind_of(props)))
    return sorted(found, key=lambda s: (not s.default, s.label.lower()))


def exclusions(config=None):
    """The patterns from the personal config. Missing file: none."""
    try:
        lines = Path(config or CONFIG).read_text().splitlines()
    except OSError:
        return []
    return [line.strip().lower() for line in lines
            if line.strip() and not line.lstrip().startswith("#")]


def hidden(sink, patterns):
    """True when a pattern is a substring of its name, description or nickname."""
    haystack = f"{sink.name} {sink.description} {sink.nick}".lower()
    return any(pattern in haystack for pattern in patterns)


def visible(config=None):
    """The sinks the menu offers: everything the config does not hide."""
    patterns = exclusions(config)
    return [sink for sink in sinks() if not hidden(sink, patterns)]


def sink_by_id(identifier, config=None):
    """The visible sink with that id, or None."""
    return next((s for s in visible(config) if s.id == identifier), None)


def sync_streams(name):
    """Move every running stream to the sink, so nothing stays behind."""
    if shutil.which("pactl") is None:
        return
    for line in out(["pactl", "list", "short", "sink-inputs"]).splitlines():
        parts = line.split("\t")
        if parts and parts[0].strip().isdigit():
            out(["pactl", "move-sink-input", parts[0].strip(), name])


def switch(sink, sync=True):
    """Make the sink the default; the OSD says which one is on now."""
    out(["wpctl", "set-default", str(sink.id)])
    if sync:
        sync_streams(sink.name)
    osd.show(sink.icon, "Audio output", sink.label, -1)


def quickshell_open():
    """Ask the panel to open. False when Quickshell is not running."""
    try:
        result = subprocess.run(["qs", "-c", "hyprflow", "ipc", "call", "sinkswitch", "toggle"],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                timeout=TIMEOUT)
    except (OSError, subprocess.SubprocessError):
        return False
    return result.returncode == 0


def pick(menu=None, config=None, sync=True):
    """The rofi fallback: choose a sink, then switch. Without sinks or on a
    dismissal it does nothing."""
    options = visible(config)
    if not options:
        return 1
    menu = menu or RofiMenu(width=520)
    index = menu.choose("Audio output", [sink.label for sink in options])
    if index is None or not 0 <= index < len(options):
        return 1
    switch(options[index], sync)
    return 0


def toggle(menu=None, config=None, sync=True):
    """Open the Quickshell panel; the rofi menu when it is not running."""
    if quickshell_open():
        return 0
    return pick(menu, config, sync)


def main(menu=None, config=None, args=()):
    args = list(args)
    sync = "--no-sync" not in args
    if "--json" in args:
        print(json.dumps([{"id": s.id, "label": s.label, "default": s.default,
                           "kind": s.kind, "icon": s.icon}
                          for s in visible(config)], ensure_ascii=False))
        return 0
    if "--set" in args:
        at = args.index("--set")
        try:
            identifier = int(args[at + 1])
        except (IndexError, ValueError):
            return 1
        sink = sink_by_id(identifier, config)
        if sink is None:
            return 1
        switch(sink, sync)
        return 0
    if "--toggle" in args:
        return toggle(menu, config, sync)
    return pick(menu, config, sync)


if __name__ == "__main__":
    sys.exit(main(args=sys.argv[1:]))
