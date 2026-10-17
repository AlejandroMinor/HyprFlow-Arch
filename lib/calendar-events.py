#!/usr/bin/env python3
"""Events for the bar's calendar: one JSON file per month, kept as history.

    calendar-events.py add TITLE START [END] [--where PLACE] [--link URL]
        START and END in local ISO time ("2026-10-17T15:00"); a date alone
        ("2026-10-20") is all day. END defaults to an hour after START, or to
        the day's end for an all-day event.
        Prints the event's key.
    calendar-events.py add -            the same from JSON on stdin: one
        {"title", "start", "end"?, "where"?, "link"?, "notes"?}, a list, or
        several one after another (all or none); without a link, the call's
        is taken from the notes; a ```json fence around it is fine
    calendar-events.py edit KEY [--title T] [--start S] [--end E] [--where P] [--link URL]
        changes those; a new start alone keeps the length. Prints the new key.
    calendar-events.py remove KEY       deletes it (the key `list` shows)
    calendar-events.py list [YYYY-MM]   that month's events (default: this one)
    calendar-events.py upcoming [N]     the next N (default 5), in progress first

~/.local/share/hyprflow/calendar/YYYY-MM.json is a list of
{"title", "start", "end", "where", "link"}, filed under the month the event starts
in and sorted by start. The link (a Teams, Meet or Zoom call) opens on a
click in the bar. Anything may write these files (a sync from Outlook
or Google, later): the bar reads them itself and redraws when they change.
An event stays upcoming until its end, so one in progress is never dropped.
Adding one already there (same start and title) changes nothing.
Its key is the start and title hashed (key()), so events written by anything
else have one too; the bar computes the same to delete them.
"""
import hashlib
import json
import os
import re
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow import paths  # noqa: E402

ROOT = paths.HYPRFLOW_DATA / "calendar"


def parse(text):
    """A local datetime from ISO text; a bare date is its midnight. One with
    a zone ("…-06:00", "…Z", as iOS Shortcuts sends) becomes local time."""
    try:
        moment = datetime.fromisoformat(text)
    except ValueError:
        return datetime.combine(date.fromisoformat(text), datetime.min.time())
    return moment.astimezone().replace(tzinfo=None) if moment.tzinfo else moment


def event(title, start, end=None, where="", link=""):
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
    return {"title": title, "start": begins.strftime(stamp), "end": ends.strftime(stamp),
            "where": where, "link": link}


def key(e):
    """Six hex digits naming an event: md5 of "START TITLE" (the bar's Qt.md5)."""
    return hashlib.md5(f"{e['start']} {e['title']}".encode()).hexdigest()[:6]


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

    def write(self, month, events):
        self.root.mkdir(parents=True, exist_ok=True)
        # Atomic: the bar never reads a half written file.
        part = self.file(month).with_suffix(".json.part")
        part.write_text(json.dumps(events, indent=2, ensure_ascii=False) + "\n")
        os.replace(part, self.file(month))

    def add(self, new):
        """Files NEW; one already there (same start and title) is kept as is,
        so sending a day twice adds nothing."""
        month = new["start"][:7]
        events = self.month(month)
        if any(key(e) == key(new) for e in events):
            return False
        self.write(month, sorted(events + [new], key=lambda e: e["start"]))
        return True

    def find(self, wanted):
        """The first event with that key, in any month, or None."""
        for path in sorted(self.root.glob("*.json")):
            for e in self.month(path.stem):
                if key(e) == wanted:
                    return e
        return None

    def remove(self, wanted):
        """Deletes the first event with that key, in any month; returns it, or None."""
        for path in sorted(self.root.glob("*.json")):
            events = self.month(path.stem)
            for e in events:
                if key(e) == wanted:
                    events.remove(e)
                    self.write(path.stem, events)
                    return e
        return None

    def around(self, now):
        return [e for m in months_around(now) for e in self.month(m)]


def edited(old, changes):
    """OLD with CHANGES ({"title", "start", ...}) as a new event; a start
    moved without an end keeps the event's length."""
    start = changes.get("start", old["start"])
    end = changes.get("end")
    if end is None:
        length = parse(old["end"]) - parse(old["start"])
        end = (parse(start) + length).strftime("%Y-%m-%dT%H:%M")
    return event(changes.get("title", old["title"]), start, end,
                 changes.get("where", old.get("where", "")), changes.get("link", old.get("link", "")))


def unfenced(text):
    """TEXT without the ```json … ``` a language model wraps its JSON in."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        text = text.rsplit("```", 1)[0]
    return text


def read_many(text):
    """The events in TEXT: one JSON object, a list, or several in a row (iOS
    Shortcuts joining one dictionary per event)."""
    # strict=False: notes keep their raw new lines, which strict JSON refuses.
    decoder, found = json.JSONDecoder(strict=False), []
    text = text.strip()
    while text:
        # The Shortcut wraps each dictionary in one more pair: {{"title": …}}.
        wrapped = text.startswith("{{")
        value, end = decoder.raw_decode(text, 1 if wrapped else 0)
        if wrapped:
            end = text.index("}", end) + 1
        found += value if isinstance(value, list) else [value]
        text = text[end:].lstrip(", \r\n\t ")
    if not found:
        raise ValueError("no events")
    return found


CALL_HOSTS = ("teams.microsoft.com", "teams.live.com", "meet.google.com", "zoom.us")


def call_link(notes):
    """The meeting's URL in an event's notes: a known call service's first, else none."""
    urls = re.findall(r"https?://[^\s<>\"')\]]+", notes)
    return next((u for u in urls if any(host in u for host in CALL_HOSTS)), "")


def take_options(args, names):
    """ARGS without `--name value` pairs, and those values by name."""
    found = {}
    for name in names:
        if name in args:
            at = args.index(name)
            found[name[2:]] = " ".join(args[at + 1:at + 2])
            args = args[:at] + args[at + 2:]
    return args, found


def line(e):
    where = f"  @ {e['where']}" if e.get("where") else ""
    return f"{key(e)}  {e['start'].replace('T', ' ')} - {e['end'][11:]}  {e['title']}{where}"


def main(args, calendar=None, now=None, stdin=None):
    calendar = calendar or Calendar()
    now = now or datetime.now()
    if args == ["add", "-"]:
        try:
            given = read_many(unfenced((stdin or sys.stdin).read()))
            new = [event(g["title"], g["start"], g.get("end") or None, g.get("where") or "",
                         g.get("link") or call_link(g.get("notes") or ""))
                   for g in given]
        except (ValueError, KeyError, TypeError, AttributeError) as error:
            print(f"bad event: {error}", file=sys.stderr)
            return 1
        for e in new:
            calendar.add(e)
            print(key(e))
        return 0
    if args[:1] == ["add"] and len(args) >= 3:
        args, options = take_options(args, ["--where", "--link"])
        try:
            new = event(args[1], args[2], args[3] if len(args) > 3 else None,
                        options.get("where", ""), options.get("link", ""))
        except ValueError as error:
            print(error, file=sys.stderr)
            return 1
        calendar.add(new)
        print(key(new))
        return 0
    if args[:1] == ["edit"] and len(args) >= 2:
        args, changes = take_options(args, ["--title", "--start", "--end", "--where", "--link"])
        old = calendar.find(args[1])
        if old is None:
            print(f"no event {args[1]}", file=sys.stderr)
            return 1
        try:
            new = edited(old, changes)
        except ValueError as error:
            print(error, file=sys.stderr)
            return 1
        calendar.remove(args[1])
        calendar.add(new)
        print(key(new))
        return 0
    if args[:1] == ["remove"] and len(args) == 2:
        if calendar.remove(args[1]) is None:
            print(f"no event {args[1]}", file=sys.stderr)
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
