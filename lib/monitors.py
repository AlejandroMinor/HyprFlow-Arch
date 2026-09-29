#!/usr/bin/env python3
"""Monitor layouts for Hyprland and the Waybar bars that go with them.

    monitors.sh list                         what is connected, and its modes
    monitors.sh setup                        wizard: build the profile for this set
    monitors.sh apply                        load the profile for this set (default)
    monitors.sh mirror [on [MONITOR]|off|toggle]
    monitors.sh solo [on [MONITOR [MODE]]|off|toggle]

A profile is the layout for one set of connected monitors (keyed by their
descriptions), saved in ~/.config/hypr/monitor-profiles.json. apply writes it
out as ~/.config/hypr/monitors_active.lua (monitor rules and workspaces) and
~/.config/waybar/config (a bar per monitor, from waybar/bars.json), then
reloads only what changed.

Layout: the pure parts (the default profile, mirror, solo, the generated Lua
and bars) are functions of their inputs, for the tests. Profiles is a
Repository over the JSON files; Monitors does the rest against Hyprland.
bin/monitors.sh is a one line wrapper, so the command keeps its name.
"""

import fcntl
import json
import math
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from glob import glob
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import hyprctl, notify, paths  # noqa: E402

LIB = Path(__file__).resolve().parent
HYPR = paths.CONFIG / "hypr"
WAYBAR = paths.CONFIG / "waybar"
PROFILES = HYPR / "monitor-profiles.json"
UNMIRRORED = HYPR / "monitor-profiles.unmirrored.json"
SOLO_STATE = HYPR / "monitor-solo.json"
ACTIVE_LUA = HYPR / "monitors_active.lua"
WAYBAR_CONFIG = WAYBAR / "config"
BARS_TEMPLATE = WAYBAR / "bars.json"
GAME_MODE_STATE = paths.HYPRFLOW_STATE / "game-mode"
LOCK = Path("/tmp/monitors-apply.lock")
LOCK_WAIT = 30  # seconds

USAGE = ("usage: monitors.sh [list|setup|apply|mirror [on [MONITOR]|off|toggle]|"
         "solo [on [MONITOR [MODE]]|off|toggle]]")


# ── messages ──────────────────────────────────────────────────────────────

def msg(text):
    print(f"\033[1;34m󰍹 monitors:\033[0m {text}", flush=True)


def warn(text):
    print(f"\033[1;33m󰍹 monitors:\033[0m {text}", file=sys.stderr, flush=True)


class Stop(Exception):
    """A command that cannot go on: warned, exit 1."""


# ── pure ──────────────────────────────────────────────────────────────────

def scale_of(value):
    """A monitor scale, as given, if Hyprland can use it; ValueError if not
    (0, a negative, true, 1e999: a hand edited profile or a typo)."""
    if isinstance(value, bool) or not isinstance(value, (int, float)) \
            or not math.isfinite(value) or not 0 < value <= 8:
        raise ValueError(f"invalid scale: {value!r}")
    return value


def number(value):
    """A JSON number as jq prints it: 1 stays 1, 1.0 stays 1.0."""
    return repr(value) if isinstance(value, float) else str(value)


def no_hz(mode):
    return re.sub(r"Hz$", "", mode)


def clean_rate(mode):
    """1920x1080@60.00 -> 1920x1080@60; 59.94 keeps its decimals."""
    return re.sub(r"\.0+$", "", mode)


def signature(detected):
    """The key of a monitor set: its descriptions, sorted."""
    return "|".join(sorted(m["description"] for m in detected))


def port_for(detected, description):
    return next((m["name"] for m in detected if m["description"] == description), None)


def modes_of(detected, description):
    return [no_hz(mode) for m in detected if m["description"] == description
            for mode in m.get("availableModes", [])]


def default_profile(detected):
    """Every monitor side by side at its preferred mode, the largest one
    primary with the full bar."""
    areas = [m["width"] * m["height"] for m in detected]
    primary = areas.index(max(areas)) if areas else -1
    profile = []
    for i, m in enumerate(detected):
        modes = m.get("availableModes") or [f"{m['width']}x{m['height']}@60Hz"]
        entry = {"description": m["description"], "mode": no_hz(modes[0]), "scale": m["scale"],
                 "transform": 0, "primary": i == primary}
        entry["bar"] = "full" if entry["primary"] or m["name"].startswith("eDP") else "minimal"
        profile.append(entry)
    return profile


def transform_of(entry):
    if "transform" in entry and entry["transform"] is not None:
        return entry["transform"]
    return 3 if entry.get("orientation") == "v" else 0


def logical_width(entry):
    """Width the monitor takes in the layout: its height when rotated 90°."""
    size = entry["mode"].split("@")[0]
    w, h = (int(v) for v in size.split("x"))
    side = h if transform_of(entry) % 2 else w
    return int(side / scale_of(entry["scale"]))


def mirrorize(profile, source, detected):
    """Every monitor clones `source`, at the largest resolution they all offer,
    each at the refresh rate closest to the one it had."""
    def resolution(mode):
        return mode.split("@")[0]

    def hz(mode):
        rate = mode.split("@")[1] if "@" in mode else "60"
        return float(rate)

    per_monitor = [list(dict.fromkeys(resolution(m) for m in modes_of(detected, e["description"])))
                   for e in profile]
    common = None
    if per_monitor:
        shared = per_monitor[0]
        for resolutions in per_monitor[1:]:
            shared = [r for r in shared if r in resolutions]
        if shared:
            common = max(shared, key=lambda r: [int(v) for v in r.split("x")][0] * int(r.split("x")[1]))
    mirrored = []
    for entry in profile:
        entry = dict(entry)
        if common:
            candidates = [m for m in modes_of(detected, entry["description"]) if resolution(m) == common]
            if candidates:
                best = min(candidates, key=lambda m: abs(hz(m) - hz(entry["mode"])))
                entry["mode"] = clean_rate(best)
        if entry["description"] == source:
            entry["primary"] = True
            entry.pop("mirror", None)
        else:
            entry["primary"] = False
            entry["transform"] = 0
            entry["mirror"] = source
        mirrored.append(entry)
    return mirrored


def solo_profile(detected, entry):
    """The solo screen as recorded, and every other connected one off."""
    return [entry] + [{"description": m["description"], "disabled": True, "bar": "none"}
                      for m in detected if m["description"] != entry["description"]]


def generate(profile, detected, bars_template=None, connected=lambda port: True):
    """(monitors_active.lua text, Waybar bars or None without a template).

    A disabled monitor is switched off explicitly: Hyprland turns on any
    monitor it has no rule for. One that Hyprland lists but the connector
    reports gone (a DisplayPort screen asleep) is left out, since enabling it
    fails the whole commit; the hotplug apply adds it when it wakes."""
    rules, workspaces = [], []
    x, pair = 0, 3
    for entry in profile:
        port = port_for(detected, entry["description"])
        if port is None:
            continue
        if not entry.get("disabled") and not connected(port):
            continue
        if entry.get("disabled"):
            rules.append(f'hl.monitor({{ output = "{port}", disabled = true }})')
            continue
        mirror_port = port_for(detected, entry["mirror"]) if entry.get("mirror") else None
        if mirror_port:
            rules.append(f'hl.monitor({{ output = "{port}", mode = "{entry["mode"]}", position = "auto", '
                         f'scale = {number(scale_of(entry["scale"]))}, mirror = "{mirror_port}" }})')
            continue
        transform = transform_of(entry)
        rules.append(f'hl.monitor({{ output = "{port}", mode = "{entry["mode"]}", position = "{x}x0", '
                     f'scale = {number(scale_of(entry["scale"]))}, transform = {transform} }})')
        layout = ', layout_opts = { orientation = "top" }' if transform % 2 else ""
        numbers = (1, 2) if entry.get("primary") else (pair, pair + 1)
        if not entry.get("primary"):
            pair += 2
        workspaces += [f'hl.workspace_rule({{ workspace = "{n}", monitor = "{port}"{layout} }})'
                       for n in numbers]
        x += logical_width(entry)

    lua = ("-- monitors_active.lua — GENERATED by monitors.sh. Do not edit by hand.\n"
           "-- Run `monitors.sh setup` to change the layout.\n\n"
           + "".join(f"{r}\n" for r in rules) + "\n"
           + "".join(f"{w}\n" for w in workspaces) + "\n")
    if bars_template is None:
        return lua, None

    bars = []
    for entry in profile:
        if entry.get("bar") == "none" or entry.get("mirror") or entry.get("disabled"):
            continue
        port = port_for(detected, entry["description"])
        if port is None:
            continue
        archetype = bars_template.get(entry.get("bar"))
        if not archetype:
            warn(f"bar type '{entry.get('bar')}' not in bars.json; skipping")
            continue
        logical = logical_width(entry)
        width = logical - 120 if logical - 120 >= 400 else logical
        bar = {k: v for k, v in archetype.items() if k != "_comment"}
        bar["output"] = [port]
        bar.setdefault("width", width)
        bars.append(bar)
    return lua, bars


def resolution_choices(monitor):
    """[(resolution, [rates fastest first])], largest resolution first."""
    rates = {}
    for mode in monitor.get("availableModes", []):
        res, _, rate = no_hz(mode).partition("@")
        rate = re.sub(r"\.0+$", "", rate)
        rates.setdefault(res, [])
        if rate not in rates[res]:
            rates[res].append(rate)
    def area(res):
        w, h = res.split("x")
        return int(w) * int(h)
    return [(res, sorted(r, key=float, reverse=True))
            for res, r in sorted(rates.items(), key=lambda item: area(item[0]), reverse=True)]


def listing(detected):
    rows = [("IDX", "DESCRIPTION (identifier)", "PORT", "CURRENT", "PREFERRED")]
    for i, m in enumerate(detected):
        rate = round(m["refreshRate"] * 100) / 100
        rate = int(rate) if rate == int(rate) else rate
        current = "off" if m.get("disabled") else f"{m['width']}x{m['height']}@{rate}Hz"
        rows.append((str(i), m["description"], m["name"], current, (m.get("availableModes") or ["?"])[0]))
    widths = [max(len(row[c]) for row in rows) for c in range(len(rows[0]))]
    lines = ["  ".join(cell.ljust(widths[c]) for c, cell in enumerate(row)).rstrip() for row in rows]
    return "\n".join(lines) + "\n\nUse the DESCRIPTION column verbatim in Waybar / profiles.\n"


# ── storage (Repository) ──────────────────────────────────────────────────

class Profiles:
    """Saved layouts by monitor set, in one JSON file."""

    def __init__(self, path=None):
        self.path = Path(path or PROFILES)  # read at call time, not at import

    def load(self):
        try:
            return json.loads(self.path.read_text())
        except (OSError, ValueError):
            return {}

    def get(self, sig):
        return self.load().get(sig)

    def save(self, sig, entries):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        data = self.load()
        data[sig] = entries
        self.path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


# ── the running session ───────────────────────────────────────────────────

def port_connected(port):
    """True unless the kernel reports the connector disconnected (or cannot say)."""
    for status in glob(f"/sys/class/drm/card*-{port}/status"):
        try:
            return Path(status).read_text().split()[0] == "connected"
        except (OSError, IndexError):
            return True
    return True


def detect():
    return hyprctl.query("monitors", "all")


def write_if_changed(path, text):
    """Writes and returns True only when the content differs."""
    try:
        if path.read_text() == text:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return True


def waybar_running():
    return subprocess.run(["pgrep", "-x", "waybar"], capture_output=True).returncode == 0


def restore_workspaces():
    """Moves every workspace sitting on the wrong monitor back to the one its
    rule names: Hyprland moves a monitor's workspaces away when it goes off
    (solo, mirror, unplug) and leaves them there when it comes back."""
    try:
        rules = re.findall(r'workspace = "(\d+)", monitor = "([^"]+)"', ACTIVE_LUA.read_text())
    except OSError:
        return
    if not rules:
        return
    workspaces = {w["id"]: w["monitor"] for w in hyprctl.query("workspaces")}
    enabled = {m["name"] for m in hyprctl.query("monitors")}
    focused = hyprctl.query("activeworkspace")["id"]
    moved = False
    for ws, mon in rules:
        ws = int(ws)
        if mon not in enabled or workspaces.get(ws) in (None, mon):
            continue
        hyprctl.dispatch(f"hl.dsp.focus({{ workspace = {ws} }})")
        hyprctl.dispatch(f'hl.dsp.workspace.move({{ monitor = "{mon}" }})')
        moved = True
    if moved:
        hyprctl.dispatch(f"hl.dsp.focus({{ workspace = {focused} }})")


def apply(profile=None):
    """Writes the layout for the monitors connected now and reloads what
    changed. Without a profile: solo while it is on, else the saved one for
    this set, else the default."""
    detected = detect()
    sig = signature(detected)
    used_default = False

    # Solo is a state, not a profile: a switched off DisplayPort monitor
    # reports itself disconnected once asleep, which changes the set; keyed on
    # the set, solo would fall back and wake everything up.
    if profile is None and SOLO_STATE.exists():
        try:
            state = json.loads(SOLO_STATE.read_text())
        except ValueError:
            state = None
        if state and any(m["description"] == state["entry"]["description"] for m in detected):
            profile = solo_profile(detected, state["entry"])
            msg(f"solo on: {state['entry']['description']}")

    if profile is None:
        profile = Profiles().get(sig)
        if profile is not None:
            msg("profile found for this monitor set")
        else:
            profile = default_profile(detected)
            used_default = True
            msg("no profile for this set → using default (horizontal, primary=largest)")

    try:
        template = json.loads(BARS_TEMPLATE.read_text())
    except (OSError, ValueError):
        template = None
        warn(f"{BARS_TEMPLATE} not found; skipping waybar regeneration")
    lua, bars = generate(profile, detected, template, port_connected)

    lua_changed = write_if_changed(ACTIVE_LUA, lua)
    bars_changed = bars is not None and write_if_changed(
        WAYBAR_CONFIG, json.dumps(bars, indent=2, ensure_ascii=False) + "\n")

    if lua_changed:
        msg("layout changed; reloading Hyprland…")
        subprocess.run(["hyprctl", "reload"], capture_output=True)
        # A monitor switched back on comes up without its wallpaper, and the
        # monitors must be on to take their workspaces back: both a moment
        # later, detached.
        subprocess.Popen(["sh", "-c", "sleep 1; command -v awww >/dev/null && awww restore"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        subprocess.Popen([sys.executable, __file__, "_restore-workspaces"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    # game-mode.sh hides Waybar and brings it back itself when it ends.
    if GAME_MODE_STATE.exists():
        msg("game mode on: leaving Waybar hidden")
    elif bars_changed or not waybar_running():
        subprocess.run([str(LIB / "waybar-restart.sh")])
        msg("Waybar (re)started")

    if not lua_changed and not bars_changed:
        msg("no changes")
    if used_default:
        notify.send("Monitors", "Using default layout. Run 'monitors.sh setup' to customize.", app="Monitors")


# ── commands ──────────────────────────────────────────────────────────────

def saved_or_default(detected):
    return Profiles().get(signature(detected)) or default_profile(detected)


def match(detected, name):
    """A monitor's description from its port or its description."""
    return next((m["description"] for m in detected if name in (m["name"], m["description"])), None)


def cmd_list():
    print(listing(detect()), end="")


def cmd_mirror(action="toggle", source=""):
    detected = detect()
    sig = signature(detected)
    if len(detected) < 2:
        raise Stop("mirror needs at least 2 monitors")
    profile = saved_or_default(detected)
    mirrored = any(e.get("mirror") for e in profile)
    if action == "toggle":
        action = "off" if mirrored else "on"
    if action == "on":
        if source:
            description = match(detected, source)
            if description is None:
                raise Stop(f"unknown monitor: {source}")
            source = description
        else:
            source = next((e for e in profile if e.get("primary")), profile[0])["description"]
        if not mirrored:  # remember the extended layout, for mirror off
            Profiles(UNMIRRORED).save(sig, profile)
        profile = mirrorize(profile, source, detected)
        msg(f"mirroring onto: {source}")
    elif action == "off":
        profile = Profiles(UNMIRRORED).get(sig) or default_profile(detected)
        msg("mirror off: back to extended layout")
    else:
        raise Stop("usage: monitors.sh mirror [on [MONITOR]|off|toggle]")
    Profiles().save(sig, profile)
    apply()


def cmd_solo(action="toggle", target="", mode=""):
    """solo on [MONITOR [MODE]]: only that monitor stays on (the primary one
    when none is given), optionally in another mode. The saved profiles are
    left alone: solo lives in its own state file, which apply honours."""
    detected = detect()
    sig = signature(detected)
    if action == "toggle":
        action = "off" if SOLO_STATE.exists() else "on"
    if action == "on":
        profile = saved_or_default(detected)
        if not target:
            target = next((e for e in profile if e.get("primary")), profile[0])["description"]
        description = match(detected, target)
        if description is None:
            raise Stop(f"unknown monitor: {target}")
        if mode and not any(m == mode or m.startswith(mode + ".") for m in modes_of(detected, description)):
            raise Stop(f"{description} does not offer {mode}")
        entry = next((e for e in profile if e["description"] == description), None) \
            or next(e for e in default_profile(detected) if e["description"] == description)
        entry = {k: v for k, v in entry.items() if k not in ("disabled", "mirror")}
        entry["primary"] = True
        if entry.get("bar") in (None, "none"):
            entry["bar"] = "full"
        if mode:
            entry["mode"] = mode
        SOLO_STATE.parent.mkdir(parents=True, exist_ok=True)
        SOLO_STATE.write_text(json.dumps({"entry": entry, "sig": sig}, indent=2, ensure_ascii=False) + "\n")
        apply()
    elif action == "off":
        if not SOLO_STATE.exists():
            msg("solo is already off")
            return
        # The layout of the set connected when solo began, even if a monitor
        # is still asleep: generate skips it and the hotplug apply adds it.
        was = json.loads(SOLO_STATE.read_text())["sig"]
        SOLO_STATE.unlink()
        msg("solo off: back to the previous layout")
        apply(Profiles().get(was))
    else:
        raise Stop("usage: monitors.sh solo [on [MONITOR [MODE]]|off|toggle]")


@dataclass
class Tty:
    """Questions for the setup wizard, on the terminal even when stdin is not."""
    stream: object

    def ask(self, prompt, default=""):
        print(prompt, end="", flush=True)
        answer = self.stream.readline()
        return answer.strip() or default


def pick(tty, prompt, count, default):
    choice = tty.ask(prompt, str(default))
    return int(choice) if choice.isdigit() and 1 <= int(choice) <= count else default


def cmd_setup(tty=None):
    tty = tty or Tty(open("/dev/tty"))
    detected = detect()
    if not detected:
        raise Stop("no monitors detected")
    msg(f"Detected {len(detected)} monitor(s):")
    print(listing(detected))

    entries, disabled = [], []
    for m in detected:
        description, port = m["description"], m["name"]
        print(f"\n\033[1m── {description} ({port}) ──\033[0m")
        if tty.ask("  Enable this monitor? [Y/n]: ", "y").lower().startswith("n"):
            print("  → disabled")
            disabled.append({"description": description, "disabled": True, "bar": "none"})
            continue

        # Resolution: the preferred one by default. A TV often prefers 4K at
        # 30 Hz where 1080p at 60 Hz plays far better, so offer every one,
        # largest first, with every rate it offers.
        preferred = clean_rate(no_hz((m.get("availableModes") or [f"{m['width']}x{m['height']}@60Hz"])[0]))
        resolution = preferred.split("@")[0]
        choices = resolution_choices(m)
        if len(choices) > 1:
            default = next((i + 1 for i, (r, _) in enumerate(choices) if r == resolution), 1)
            print("    Resolution (refresh rates):")
            for i, (res, rates) in enumerate(choices, 1):
                print(f"      {i:2d}) {res:<10} {' / '.join(rates)} Hz")
            resolution = choices[pick(tty, f"  Resolution [1-{len(choices)}] (default {default}, preferred): ",
                                      len(choices), default) - 1][0]

        # Refresh: the preferred mode is often 60 Hz even on high refresh
        # panels, so default to the fastest one at that resolution.
        rates = next((r for res, r in choices if res == resolution), [])
        mode = preferred
        if rates:
            choice = 1
            if len(rates) > 1:
                print(f"    Refresh rate at {resolution}:" + "".join(f"  {i}) {r} Hz" for i, r in enumerate(rates, 1)))
                choice = pick(tty, f"  Refresh [1-{len(rates)}] (default 1): ", len(rates), 1)
            mode = f"{resolution}@{rates[choice - 1]}"

        print("    Rotation: 0=normal  1=90°(portrait)  2=180°(flipped)  3=270°(portrait)")
        print("              4-7 = mirrored (4=normal, 5=90°, 6=180°, 7=270°)")
        transform = tty.ask("  Transform [0-7] (default 0): ", "0")
        transform = int(transform) if transform in "01234567" and len(transform) == 1 else 0
        scale = tty.ask(f"  Scale (default {number(m['scale'])}): ", number(m["scale"]))
        try:
            scale = scale_of(json.loads(scale))
        except ValueError:
            print(f"  → not a usable scale, keeping {number(m['scale'])}")
            scale = m["scale"]
        bar = tty.ask("  Waybar bar: [f]ull / [m]inimal / [n]one (default f): ", "f").lower()
        bar = "minimal" if bar.startswith("m") else "none" if bar.startswith("n") else "full"
        entries.append({"description": description, "mode": mode, "scale": scale,
                        "transform": transform, "primary": False, "bar": bar})

    if not entries:
        raise Stop("no monitors enabled")

    print("\n\033[1mOrder left → right\033[0m (enabled monitors):")
    for j, e in enumerate(entries):
        print(f"  {j}) {e['description']}")
    order = tty.ask(f"  Indices separated by space (default 0..{len(entries) - 1}): ")
    if order:
        picked = [int(i) for i in order.split() if i.isdigit()]
        if sorted(picked) == list(range(len(entries))):
            entries = [entries[i] for i in picked]
        else:
            print(f"  → not every index from 0 to {len(entries) - 1} once, keeping the order")

    print("\n\033[1mPrimary monitor\033[0m (gets workspaces 1 and 2):")
    for j, e in enumerate(entries):
        print(f"  {j}) {e['description']}")
    primary = tty.ask("  Primary index (default 0): ", "0")
    primary = int(primary) if primary.isdigit() else 0
    if primary >= len(entries):
        print(f"  → no monitor {primary}, the primary is 0")
        primary = 0
    for j, e in enumerate(entries):
        e["primary"] = j == primary

    sig = signature(detected)
    if len(entries) > 1:
        print("\n\033[1mMirror\033[0m (every monitor clones the primary, same resolution):")
        if tty.ask("  Mirror mode? [y/N]: ", "n").lower().startswith("y"):
            Profiles(UNMIRRORED).save(sig, entries)
            source = next(e["description"] for e in entries if e["primary"])
            entries = mirrorize(entries, source, detected)

    Profiles().save(sig, entries + disabled)
    msg(f"profile saved for: {sig}")
    apply()


def take_lock():
    """Waits for a running apply instead of skipping: at login several run
    at once, and the last one is the only one that saw every monitor."""
    handle = open(LOCK, "w")
    deadline = time.monotonic() + LOCK_WAIT
    while True:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return handle
        except OSError:
            if time.monotonic() > deadline:
                warn("another run is stuck, skipping")
                sys.exit(0)
            time.sleep(0.2)


def main(argv):
    command, args = (argv[1] if len(argv) > 1 else "apply"), argv[2:]
    try:
        if command == "list":
            cmd_list()
        elif command == "setup":
            cmd_setup()
        elif command == "_restore-workspaces":
            time.sleep(1)
            restore_workspaces()
        elif command in ("apply", "mirror", "solo"):
            with take_lock():
                if command == "apply":
                    apply()
                elif command == "mirror":
                    cmd_mirror(*args[:2])
                else:
                    cmd_solo(*args[:3])
        else:
            raise Stop(USAGE)
    except (Stop, ValueError) as stop:
        warn(str(stop))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
