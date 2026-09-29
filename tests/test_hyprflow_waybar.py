"""Tests for lib/hyprflow/waybar.py, the skeleton shared by the event driven
Waybar modules. Fake modules drive it; nothing touches Waybar or the kernel."""

import json

import pytest


class Stop(BaseException):
    """Breaks out of run(), which otherwise loops forever. BaseException, since
    run() catches every Exception to keep the module alive."""


def make_module(waybar_module, states, rounds):
    """A module whose state follows `states`, one per emit(), and whose event
    source yields `rounds[i]` times on its i-th start, then stops the test."""

    class Fake(waybar_module.WaybarModule):
        def __init__(self):
            super().__init__()
            self.states = iter(states)
            self.starts = 0

        def state(self):
            return next(self.states)

        def events(self):
            if self.starts == len(rounds):
                raise Stop
            n = rounds[self.starts]
            self.starts += 1
            for _ in range(n):
                yield

    return Fake()


def printed(capsys):
    return [json.loads(line) for line in capsys.readouterr().out.splitlines()]


@pytest.fixture(autouse=True)
def no_side_effects(waybar_module, monkeypatch):
    monkeypatch.setattr(waybar_module, "die_with_parent", lambda: None)
    monkeypatch.setattr(waybar_module.os, "getppid", lambda: 4242)
    monkeypatch.setattr(waybar_module.time, "sleep", lambda s: None)
    monkeypatch.setattr(waybar_module.syslog, "syslog", lambda *a: None)


def test_emit_skips_a_state_identical_to_the_last(waybar_module, capsys):
    a, b = {"text": "a"}, {"text": "b"}
    module = make_module(waybar_module, [a, a, b, b, a], [])
    for _ in range(5):
        module.emit()
    assert printed(capsys) == [a, b, a]


def test_run_emits_at_start_and_on_every_event(waybar_module, capsys):
    s = [{"text": str(i)} for i in range(4)]
    # start, 2 events, then the source ends: one more emit after the restart
    module = make_module(waybar_module, s, [2])
    with pytest.raises(Stop):
        module.run()
    assert printed(capsys) == s


def test_run_starts_an_ended_event_source_again(waybar_module, capsys):
    module = make_module(waybar_module, [{"n": i} for i in range(10)], [1, 1, 1])
    with pytest.raises(Stop):
        module.run()
    assert module.starts == 3


def test_run_survives_a_failing_state_and_backs_off(waybar_module, monkeypatch, capsys):
    waits, journal = [], []
    monkeypatch.setattr(waybar_module.time, "sleep", waits.append)
    monkeypatch.setattr(waybar_module.syslog, "syslog", lambda level, msg: journal.append(msg))

    class Flaky(waybar_module.WaybarModule):
        calls = 0

        def state(self):
            self.calls += 1
            if self.calls <= 3:
                raise ValueError("no data yet")
            return {"text": "ok"}

        def events(self):
            raise Stop
            yield

    with pytest.raises(Stop):
        Flaky().run()
    out = capsys.readouterr()
    assert [json.loads(line) for line in out.out.splitlines()] == [{"text": "ok"}]
    assert waits == [1.0, 2.0, 4.0]
    assert out.err.count("no data yet") == 3
    assert len(journal) == 3 and "Flaky: ValueError('no data yet')" in journal[0]


def test_run_exits_if_waybar_is_already_gone(waybar_module, monkeypatch, capsys):
    monkeypatch.setattr(waybar_module.os, "getppid", lambda: 1)
    module = make_module(waybar_module, [{"text": "x"}], [])
    with pytest.raises(SystemExit):
        module.run()
    assert capsys.readouterr().out == ""


def test_lines_streams_a_commands_output(waybar_module):
    assert list(waybar_module.lines(["printf", "one\\ntwo\\n"])) == ["one\n", "two\n"]


def test_lines_left_early_stops_its_command_at_once(waybar_module):
    import time as real_time
    started = real_time.monotonic()
    for _ in waybar_module.lines(["bash", "-c", "echo first; sleep 30"]):
        break   # as when state() fails mid stream
    assert real_time.monotonic() - started < 5
