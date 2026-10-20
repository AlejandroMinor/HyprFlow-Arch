#!/usr/bin/env python3
"""Batteries pushed from elsewhere, for battery-hub: an iOS Shortcut sends
the iPhone's, the Watch's, the iPad's… over SSH.

    battery-push.py add -    read them from stdin: {"name": percent, …} (what
                             the Shortcut sends), or a list of {"name",
                             "percent", "charging"?}
    battery-push.py list     what is kept, and how long ago it came
    battery-push.py clear    forget them all

Kept in ~/.local/state/hyprflow/pushed-batteries.json, {name: {percent,
charging, at}}; a push replaces only the devices it names. battery-hub shows
each one for a day after it came, with that time, (PushedSource), then drops it: a
level that stopped coming is not shown as if it were current.
"""
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import paths, shortcuts  # noqa: E402

FILE = paths.HYPRFLOW_STATE / "pushed-batteries.json"


def batteries(values):
    """{name: (percent, charging)} from what the Shortcut sent. Refuses a
    percent that is not a number from 0 to 100."""
    found = {}
    for value in values:
        if not isinstance(value, dict):
            raise ValueError(f"not a battery: {value!r}")
        if "name" in value:  # {"name", "percent", "charging"?}
            pairs = [(value["name"], value.get("percent"), bool(value.get("charging")))]
        else:                # {"name": percent, …}
            pairs = [(name, percent, False) for name, percent in value.items()]
        for name, percent, charging in pairs:
            percent = round(float(percent))
            if not 0 <= percent <= 100:
                raise ValueError(f"{name}: {percent} is not a percentage")
            found[str(name).strip()] = (percent, charging)
    return found


def load(path=FILE):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {}


def save(kept, path=FILE):
    path.parent.mkdir(parents=True, exist_ok=True)
    part = path.with_suffix(".json.part")  # battery-hub never reads half a file
    part.write_text(json.dumps(kept, indent=2, ensure_ascii=False) + "\n")
    os.replace(part, path)


def main(args, path=FILE, stdin=None, now=None):
    now = time.time() if now is None else now
    if args == ["add", "-"]:
        try:
            pushed = batteries(shortcuts.read_json((stdin or sys.stdin).read()))
        except (ValueError, KeyError, TypeError) as error:
            print(f"bad batteries: {error}", file=sys.stderr)
            return 1
        kept = load(path)
        for name, (percent, charging) in pushed.items():
            kept[name] = {"percent": percent, "charging": charging, "at": round(now)}
        save(kept, path)
        return 0
    if args == ["list"]:
        for name, entry in load(path).items():
            print(f"{entry['percent']:3d}%  {name}  ({round((now - entry['at']) / 60)} min ago)")
        return 0
    if args == ["clear"]:
        save({}, path)
        return 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
