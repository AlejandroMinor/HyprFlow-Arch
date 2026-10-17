#!/usr/bin/env python3
"""Events for the bar's calendar: one JSON file per month, kept as history.

    calendar-events.py add TITLE START [END] [--where PLACE]
        START and END in local ISO time ("2026-10-17T15:00"); a date alone
        ("2026-10-20") is all day. END defaults to an hour after START, or to
        the day's end for an all-day event.
    calendar-events.py list [YYYY-MM]   that month's events (default: this one)
    calendar-events.py upcoming [N]     the next N (default 5), in progress first

~/.local/share/hyprflow/calendar/YYYY-MM.json is a list of
{"title", "start", "end", "where"}, filed under the month the event starts
in and sorted by start. Anything may write these files (a sync from Outlook
or Google, later): the bar reads them itself and redraws when they change.
An event stays upcoming until its end, so one in progress is never dropped.
"""
import json
import os
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import paths  # noqa: E402

ROOT = paths.HYPRFLOW_DATA / "calendar"


def parse(text):
    """A local datetime from ISO text; a bare date is its midnight."""
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        return datetime.combine(date.fromisoformat(text), datetime.min.time())


def event(title, start, end=None, where=""):
    """A new event as stored, END defaulted; refuses an end before its start."""
    begins = parse(start)
    all_day = len(start) == 10
    if end:
        ends = parse(end) + (timedelta(days=1) if len(end) == 10 else timedelta())
    else:
        ends = begins + (timedelta(days=1) if all_day else timedelta(hours=1))
    if ends < begins:
        raise ValueError(f"'{title}' ends before it starts")
    stamp = "%Y-%m-%dT%H:%M"
    return {"title": title, "start": begins.strftime(stamp), "end": ends.strftime(stamp), "where": where}


def upcoming(events, now, count=5):
    """What has not ended yet: in progress first, then by start."""
    left = [e for e in events if parse(e["end"]) > now]
    return sorted(left, key=lambda e: (parse(e["start"]) > now, parse(e["start"])))[:count]


def months_around(now):
    """The previous, this and the next month: where an event not over yet
    can be filed (one still running from last month, one coming next)."""
    first = now.replace(day=1)
    before = (first - timedelta(days=1)).replace(day=1)
    after = (first + timedelta(days=32)).replace(day=1)
    return [m.strftime("%Y-%m") for m in (before, first, after)]


class Calendar:
    """Repository: the only code that knows events live in monthly files."""

    def __init__(self, root=ROOT):
        self.root = root

    def file(self, month):
        return self.root / f"{month}.json"

    def month(self, month):
        try:
            return json.loads(self.file(month).read_text())
        except (OSError, ValueError):
            return []

    def add(self, new):
        month = new["start"][:7]
        events = sorted(self.month(month) + [new], key=lambda e: e["start"])
        self.root.mkdir(parents=True, exist_ok=True)
        # Atomic: the bar never reads a half written file.
        part = self.file(month).with_suffix(".json.part")
        part.write_text(json.dumps(events, indent=2, ensure_ascii=False) + "\n")
        os.replace(part, self.file(month))

    def around(self, now):
        return [e for m in months_around(now) for e in self.month(m)]


def line(e):
    where = f"  @ {e['where']}" if e.get("where") else ""
    return f"{e['start'].replace('T', ' ')} - {e['end'][11:]}  {e['title']}{where}"


def main(args, calendar=None, now=None):
    calendar = calendar or Calendar()
    now = now or datetime.now()
    if args[:1] == ["add"] and len(args) >= 3:
        where = ""
        if "--where" in args:
            at = args.index("--where")
            where = " ".join(args[at + 1:at + 2])
            args = args[:at] + args[at + 2:]
        try:
            calendar.add(event(args[1], args[2], args[3] if len(args) > 3 else None, where))
        except ValueError as error:
            print(error, file=sys.stderr)
            return 1
        return 0
    if args[:1] == ["list"]:
        for e in calendar.month(args[1] if len(args) > 1 else now.strftime("%Y-%m")):
            print(line(e))
        return 0
    if args[:1] == ["upcoming"]:
        for e in upcoming(calendar.around(now), now, int(args[1]) if len(args) > 1 else 5):
            print(line(e))
        return 0
    print(__doc__.split("\n\n")[1], file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
