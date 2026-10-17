"""Tests for lib/calendar-events.py, on a calendar in a temporary folder."""

import json
from datetime import datetime

import pytest

from conftest import load_script

NOW = datetime(2026, 10, 17, 15, 30)


@pytest.fixture
def cal():
    return load_script("calendar-events.py")


@pytest.fixture
def store(cal, tmp_path):
    return cal.Calendar(tmp_path / "calendar")


def test_an_event_ends_an_hour_later_unless_told(cal):
    assert cal.event("Standup", "2026-10-17T15:00") == {
        "title": "Standup", "start": "2026-10-17T15:00", "end": "2026-10-17T16:00", "where": ""}
    assert cal.event("Review", "2026-10-17T15:00", "2026-10-17T17:30")["end"] == "2026-10-17T17:30"


def test_a_date_alone_is_all_day(cal):
    e = cal.event("Holiday", "2026-11-02")
    assert (e["start"], e["end"]) == ("2026-11-02T00:00", "2026-11-03T00:00")
    assert cal.event("Trip", "2026-11-02", "2026-11-04")["end"] == "2026-11-05T00:00"


def test_an_end_before_the_start_is_refused(cal):
    with pytest.raises(ValueError):
        cal.event("Oops", "2026-10-17T15:00", "2026-10-17T14:00")


def test_events_are_filed_by_their_start_month_and_kept_sorted(cal, store):
    store.add(cal.event("Late", "2026-10-20T10:00"))
    store.add(cal.event("Early", "2026-10-03T09:00"))
    store.add(cal.event("Next month", "2026-11-01T09:00"))
    assert [e["title"] for e in store.month("2026-10")] == ["Early", "Late"]
    assert [e["title"] for e in store.month("2026-11")] == ["Next month"]
    data = json.loads(store.file("2026-10").read_text())
    assert data[0]["title"] == "Early"
    assert not list(store.root.glob("*.part"))  # written in one go


def test_a_month_without_a_file_has_no_events(store):
    assert store.month("1999-01") == []


def test_an_event_in_progress_stays_and_comes_first(cal):
    events = [cal.event("Later", "2026-10-17T18:00"),
              cal.event("Running", "2026-10-17T15:00", "2026-10-17T16:00"),
              cal.event("Over", "2026-10-17T13:00", "2026-10-17T14:00")]
    assert [e["title"] for e in cal.upcoming(events, NOW)] == ["Running", "Later"]


def test_an_event_that_just_ended_is_gone(cal):
    events = [cal.event("Done", "2026-10-17T14:30", "2026-10-17T15:30")]
    assert cal.upcoming(events, NOW) == []


def test_upcoming_reaches_last_months_event_still_running(cal, store):
    store.add(cal.event("Conference", "2026-09-30", "2026-10-18"))
    store.add(cal.event("Next", "2026-11-03T10:00"))
    titles = [e["title"] for e in cal.upcoming(store.around(NOW), NOW)]
    assert titles == ["Conference", "Next"]


def test_months_around_cross_the_year(cal):
    assert cal.months_around(datetime(2026, 1, 15)) == ["2025-12", "2026-01", "2026-02"]
    assert cal.months_around(datetime(2026, 12, 31)) == ["2026-11", "2026-12", "2027-01"]


def test_the_command_adds_lists_and_shows_upcoming(cal, store, capsys):
    assert cal.main(["add", "Dentist", "2026-10-17T17:00", "--where", "Centro"], store, NOW) == 0
    assert cal.main(["add", "Gym", "2026-10-18T08:00"], store, NOW) == 0
    assert cal.main(["list", "2026-10"], store, NOW) == 0
    listed = capsys.readouterr().out.splitlines()
    assert listed == ["2026-10-17 17:00 - 18:00  Dentist  @ Centro", "2026-10-18 08:00 - 09:00  Gym"]
    cal.main(["upcoming", "1"], store, NOW)
    assert capsys.readouterr().out.splitlines() == ["2026-10-17 17:00 - 18:00  Dentist  @ Centro"]


def test_a_bad_add_says_why_and_fails(cal, store, capsys):
    assert cal.main(["add", "Oops", "2026-10-17T15:00", "2026-10-17T14:00"], store, NOW) == 1
    assert "ends before it starts" in capsys.readouterr().err
    assert store.month("2026-10") == []
