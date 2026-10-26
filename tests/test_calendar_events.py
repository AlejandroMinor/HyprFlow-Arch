"""Tests for lib/calendar-events.py, on a calendar in a temporary folder."""

import hashlib
import io
import json
import time
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
        "title": "Standup", "start": "2026-10-17T15:00", "end": "2026-10-17T16:00", "where": "", "link": ""}
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
    dentist, gym = capsys.readouterr().out.split()  # add prints each key
    assert cal.main(["list", "2026-10"], store, NOW) == 0
    listed = capsys.readouterr().out.splitlines()
    assert listed == [f"{dentist}  2026-10-17 17:00 - 18:00  Dentist  @ Centro",
                      f"{gym}  2026-10-18 08:00 - 09:00  Gym"]
    cal.main(["upcoming", "1"], store, NOW)
    assert capsys.readouterr().out.splitlines() == [listed[0]]


def test_a_bad_add_says_why_and_fails(cal, store, capsys):
    assert cal.main(["add", "Oops", "2026-10-17T15:00", "2026-10-17T14:00"], store, NOW) == 1
    assert "ends before it starts" in capsys.readouterr().err
    assert store.month("2026-10") == []


def test_the_key_is_the_start_and_title_hashed(cal):
    # The bar computes the same with Qt.md5("2026-10-17T17:00 Dentist").
    e = cal.event("Dentist", "2026-10-17T17:00")
    assert cal.key(e) == hashlib.md5(b"2026-10-17T17:00 Dentist").hexdigest()[:6]
    assert cal.key({"start": "2026-10-17T17:00", "title": "Dentist", "end": "x"}) == cal.key(e)


def test_remove_finds_the_event_in_any_month(cal, store):
    store.add(cal.event("Keep", "2026-10-20T10:00"))
    store.add(cal.event("Gone", "2026-11-03T10:00"))
    gone = cal.key(store.month("2026-11")[0])
    assert store.remove(gone)["title"] == "Gone"
    assert store.month("2026-11") == []
    assert [e["title"] for e in store.month("2026-10")] == ["Keep"]
    assert store.remove(gone) is None


def test_the_command_removes_by_key(cal, store, capsys):
    cal.main(["add", "Dentist", "2026-10-17T17:00"], store, NOW)
    dentist = capsys.readouterr().out.strip()
    assert cal.main(["remove", dentist], store, NOW) == 0
    assert store.month("2026-10") == []
    assert cal.main(["remove", dentist], store, NOW) == 1
    assert "no event" in capsys.readouterr().err


def test_add_reads_json_from_stdin_one_or_many(cal, store, capsys):
    one = io.StringIO('{"title": "Dentist", "start": "2026-10-17T17:00", "where": "Centro"}')
    assert cal.main(["add", "-"], store, NOW, one) == 0
    many = io.StringIO('[{"title": "Gym", "start": "2026-10-18T08:00"},'
                       ' {"title": "Trip", "start": "2026-11-02", "end": "2026-11-04"}]')
    assert cal.main(["add", "-"], store, NOW, many) == 0
    assert len(capsys.readouterr().out.split()) == 3
    assert [e["title"] for e in store.month("2026-10")] == ["Dentist", "Gym"]
    assert store.month("2026-11")[0]["end"] == "2026-11-05T00:00"


def test_bad_json_adds_nothing(cal, store, capsys):
    for text in ['not json', '{"start": "2026-10-17T17:00"}',
                 '[{"title": "Ok", "start": "2026-10-17T17:00"}, {"title": "Bad", "start": "nope"}]']:
        assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 1
    assert "bad event" in capsys.readouterr().err
    assert store.month("2026-10") == []


def test_an_event_keeps_its_call_link(cal, store, capsys):
    url = "https://teams.microsoft.com/l/meetup-join/abc"
    assert cal.main(["add", "Daily", "2026-10-17T10:00", "--link", url, "--where", "Teams"], store, NOW) == 0
    stdin = io.StringIO('{"title": "Sync", "start": "2026-10-17T12:00", "link": "https://meet.google.com/x"}')
    assert cal.main(["add", "-"], store, NOW, stdin) == 0
    daily, sync = store.month("2026-10")
    assert (daily["link"], daily["where"]) == (url, "Teams")
    assert sync["link"] == "https://meet.google.com/x"


def test_edit_changes_only_what_it_is_told(cal, store, capsys):
    cal.main(["add", "Daily", "2026-10-17T10:00", "--where", "Teams"], store, NOW)
    daily = capsys.readouterr().out.strip()
    assert cal.main(["edit", daily, "--title", "Daily UTICT", "--link", "https://meet.google.com/x"], store, NOW) == 0
    (e,) = store.month("2026-10")
    assert (e["title"], e["start"], e["end"], e["where"], e["link"]) == (
        "Daily UTICT", "2026-10-17T10:00", "2026-10-17T11:00", "Teams", "https://meet.google.com/x")
    assert capsys.readouterr().out.strip() == cal.key(e)  # a new title, a new key


def test_a_moved_start_keeps_the_length_even_to_another_month(cal, store, capsys):
    cal.main(["add", "Review", "2026-10-31T16:00", "2026-10-31T18:30"], store, NOW)
    review = capsys.readouterr().out.strip()
    assert cal.main(["edit", review, "--start", "2026-11-02T09:00"], store, NOW) == 0
    assert store.month("2026-10") == []
    assert store.month("2026-11")[0]["end"] == "2026-11-02T11:30"


def test_a_bad_edit_keeps_the_event(cal, store, capsys):
    cal.main(["add", "Daily", "2026-10-17T10:00"], store, NOW)
    daily = capsys.readouterr().out.strip()
    assert cal.main(["edit", daily, "--end", "2026-10-17T09:00"], store, NOW) == 1
    assert cal.main(["edit", "000000", "--title", "x"], store, NOW) == 1
    assert [e["title"] for e in store.month("2026-10")] == ["Daily"]


def test_a_time_with_a_zone_is_stored_as_local_time(cal, monkeypatch):
    # iOS Shortcuts' ISO 8601: seconds and a zone; the bar compares local times.
    monkeypatch.setenv("TZ", "America/Mexico_City")
    time.tzset()
    try:
        e = cal.event("Daily", "2026-10-20T16:00:00Z", "2026-10-20T11:00:00-06:00")
        assert (e["start"], e["end"]) == ("2026-10-20T10:00", "2026-10-20T11:00")
    finally:
        monkeypatch.undo()
        time.tzset()


def test_json_in_a_model_s_code_fence_is_read(cal, store):
    answer = '```json\n[{"title": "Daily", "start": "2026-10-20T10:00"}]\n```\n'
    assert cal.main(["add", "-"], store, NOW, io.StringIO(answer)) == 0
    assert store.month("2026-10")[0]["title"] == "Daily"


def test_several_objects_in_a_row_are_read(cal, store):
    # iOS Shortcuts: one dictionary per event, joined by new lines.
    text = '{"title": "A", "start": "2026-10-20T10:00"}\n{"title": "B", "start": "2026-10-20T12:00"}\n'
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    assert [e["title"] for e in store.month("2026-10")] == ["A", "B"]


def test_the_call_link_comes_from_the_notes(cal, store):
    notes = ("Microsoft Teams meeting\nJoin: https://aka.ms/JoinTeamsMeeting\n"
             "<https://teams.microsoft.com/l/meetup-join/19%3ameeting_x>\nhttps://example.com")
    text = json.dumps({"title": "Daily", "start": "2026-10-20T10:00", "notes": notes, "link": ""})
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    assert store.month("2026-10")[0]["link"] == "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x"
    assert cal.call_link("just https://example.com") == ""


def test_empty_or_null_fields_are_left_out(cal, store):
    text = '{"title": "Daily", "start": "2026-10-20T10:00", "end": null, "where": null, "link": null}'
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    e = store.month("2026-10")[0]
    assert (e["end"], e["where"], e["link"]) == ("2026-10-20T11:00", "", "")


def test_notes_with_raw_new_lines_are_read(cal, store):
    # What the Shortcut really sends: the notes' new lines unescaped.
    text = ('{"title": "Revisiones", "start": "2026-10-19T17:30", "end": "2026-10-19T18:00", "link": "",'
            ' "notes": "Reunión de Microsoft Teams\nUnirse: https://teams.microsoft.com/meet/2796?p=kb\n'
            '¿Ayuda?<https://aka.ms/JoinTeamsMeeting>"}')
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    assert store.month("2026-10")[0]["link"] == "https://teams.microsoft.com/meet/2796?p=kb"


def test_the_shortcut_s_double_braces_are_read(cal, store):
    text = ('{{"title": "Revisiones", "start": "2026-10-19T17:30", "end": "2026-10-19T18:00"}}\r\n'
            '{{"title": "Daily", "start": "2026-10-20T10:00"}}')
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    assert [e["title"] for e in store.month("2026-10")] == ["Revisiones", "Daily"]


def test_sending_the_same_event_twice_adds_it_once(cal, store):
    text = '{"title": "Revisiones", "start": "2026-10-19T17:30"}'
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    assert cal.main(["add", "-"], store, NOW, io.StringIO(text)) == 0
    assert len(store.month("2026-10")) == 1
