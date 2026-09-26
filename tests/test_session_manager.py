"""Tests for lib/session-manager.py: the pure parts, from hyprctl-shaped
dicts, plus the menu over a temp layouts folder."""

import json
import os
import time

import pytest

MONITORS = [
    {"id": 0, "name": "HDMI-A-1", "x": 0, "y": 0},
    {"id": 1, "name": "DP-2", "x": 1080, "y": 0},
]


def client(pid, cls, ws=1, monitor=1, at=(1200, 200), floating=False):
    return {"pid": pid, "class": cls, "initialClass": cls, "workspace": {"id": ws},
            "monitor": monitor, "at": list(at), "size": [900, 600], "floating": floating}


def argv(pid):
    return {1: ["kitty"], 2: ["spotify", "--uri", "a b"], 3: ["code"]}.get(pid)


def test_snapshot_keeps_the_real_command_and_position_on_its_monitor(session):
    entries = session.snapshot([client(2, "Spotify", floating=True)], MONITORS, argv)
    assert entries == [{"workspace": 1, "command": ["spotify", "--uri", "a b"], "class": "Spotify",
                        "initialClass": "Spotify", "floating": True, "monitor": "DP-2",
                        "at": [120, 200], "size": [900, 600]}]


def test_snapshot_skips_the_desktop_and_windows_without_a_command(session):
    clients = [client(1, "kitty"), client(9, "waybar"), client(99, "ghost")]
    assert [e["class"] for e in session.snapshot(clients, MONITORS, argv)] == ["kitty"]


def test_an_app_with_several_windows_is_relaunched_once(session):
    clients = [client(3, "code", ws=1), client(3, "code", ws=2)]
    assert len(session.snapshot(clients, MONITORS, argv)) == 1


def test_a_floating_window_goes_back_to_its_monitor(session):
    entry = session.snapshot([client(2, "Spotify", floating=True)], MONITORS, argv)[0]
    calls = session.placement(entry, MONITORS, "0xabc")
    assert calls[0] == "hl.dsp.window.move({workspace='1', follow=false, window='address:0xabc'})"
    assert "hl.dsp.window.move({x=1200, y=200, window='address:0xabc'})" in calls
    assert "hl.dsp.window.resize({x=900, y=600, window='address:0xabc'})" in calls


def test_a_missing_monitor_falls_back_to_the_first(session):
    entry = {"workspace": 2, "floating": True, "monitor": "gone", "at": [10, 20], "size": [5, 5]}
    assert "hl.dsp.window.move({x=10, y=20, window='address:0x1'})" in \
        session.placement(entry, MONITORS, "0x1")


def test_a_tiled_window_only_changes_workspace(session):
    entry = {"workspace": -98, "floating": False}
    assert session.placement(entry, MONITORS, "0x1") == [
        "hl.dsp.window.move({workspace='special:magic', follow=false, window='address:0x1'})"]


def test_old_layouts_with_a_joined_command_still_launch(session):
    assert session.launch_argv("kitty --class x") == ["bash", "-c", "kitty --class x"]
    assert session.launch_argv(["kitty"]) == ["kitty"]


@pytest.mark.parametrize("seconds, text", [
    (30, "just now"), (600, "10 min ago"), (7200, "2 h ago"), (3 * 86400, "3 days ago")])
def test_ago(session, seconds, text):
    assert session.ago(seconds) == text


def test_describe_sums_up_a_layout(session):
    entries = [{"class": c, "workspace": ws} for c, ws in
               [("kitty", 1), ("kitty", 1), ("Spotify", 2), ("code", 3), ("obsidian", 3)]]
    assert session.describe(entries, 7200) == \
        "5 windows  ·  ws 1, 2, 3  ·  kitty, Spotify, code …  ·  2 h ago"


def test_the_logout_save_is_shown_as_the_last_session(session):
    assert session.title("default") == "Last session"
    assert session.title("work") == "work"


def test_layouts_are_listed_newest_first_and_bad_files_skipped(session, tmp_path):
    now = time.time()
    for name, age in (("old", 5000), ("new", 10)):
        path = tmp_path / f"{name}.json"
        path.write_text(json.dumps([{"class": "kitty", "workspace": 1}]))
        os.utime(path, (now - age, now - age))
    (tmp_path / "broken.json").write_text("{nope")
    assert session.Layouts(tmp_path, clock=lambda: now).names() == ["new", "old"]


def test_layouts_save_exists_and_delete(session, tmp_path):
    layouts = session.Layouts(tmp_path / "templates")
    assert not layouts.exists("work")
    layouts.save("work", [{"class": "kitty"}])
    assert layouts.exists("work") and layouts.all()[0][1] == [{"class": "kitty"}]
    layouts.delete("work")
    assert layouts.names() == []


# The flows, on a fake menu, desktop and notifier

class FakeMenu:
    """Answers in order: pick() takes Choice or None, ask() takes text or None."""

    def __init__(self, *answers):
        self.answers = list(answers)
        self.asked = []

    def pick(self, prompt, rows, hint):
        self.asked.append((prompt, rows))
        return self.answers.pop(0)

    def ask(self, prompt, options, hint=""):
        self.asked.append((prompt, options))
        return self.answers.pop(0)


class FakeDesktop:
    def __init__(self, windows=2, opens=True):
        self.windows, self.opens = windows, opens
        self.dispatched, self.reopened = [], []

    def capture(self):
        return [{"class": f"app{i}", "workspace": 1} for i in range(self.windows)]

    def query(self, what):
        return []

    def dispatch(self, expr):
        self.dispatched.append(expr)

    def reopen(self, entry, monitors):
        self.reopened.append(entry["class"])
        return self.opens


@pytest.fixture
def flow(session, tmp_path, monkeypatch):
    monkeypatch.setattr(session.time, "sleep", lambda s: None)
    notes = []

    def build(*answers, **desktop):
        menu, desk = FakeMenu(*answers), FakeDesktop(**desktop)
        manager = session.SessionManager(session.Layouts(tmp_path), menu, desk,
                                         lambda body, urgency="normal": notes.append(body))
        return manager, menu, desk

    return build, session.Layouts(tmp_path), notes


def test_save_under_a_new_name(flow):
    build, layouts, notes = flow
    manager, _, _ = build("my work")
    manager.save()
    assert layouts.names() == ["my-work"]
    assert notes == ["'my-work' saved: 2 windows"]


def test_saving_over_a_layout_asks_first(flow):
    build, layouts, notes = flow
    layouts.save("work", [])
    manager, menu, _ = build("work", "Cancel")
    manager.save()
    assert layouts.all()[0][1] == [] and notes == []            # kept
    manager, _, _ = build("work", "Overwrite")
    manager.save()
    assert len(layouts.all()[0][1]) == 2 and notes == ["'work' updated: 2 windows"]


def test_dismissing_save_saves_nothing(flow):
    build, layouts, _ = flow
    manager, _, _ = build(None)
    manager.save()
    assert layouts.names() == []


def test_logout_saves_the_last_session_and_exits(flow):
    build, layouts, _ = flow
    manager, _, desktop = build()
    manager.logout()
    assert layouts.names() == ["default"]
    assert desktop.dispatched == ["hl.dsp.exit()"]


def test_load_reopens_the_picked_layout(flow, session):
    build, layouts, notes = flow
    layouts.save("work", [{"class": "kitty", "workspace": 1}, {"class": "zen", "workspace": 2}])
    manager, _, desktop = build(session.Choice(0))
    manager.load()
    assert desktop.reopened == ["kitty", "zen"]
    assert notes == ["'work': 2 of 2 windows back"]


def test_load_names_what_did_not_open(flow, session):
    build, layouts, notes = flow
    layouts.save("work", [{"class": "kitty", "workspace": 1}])
    manager, _, _ = build(session.Choice(0), opens=False)
    manager.load()
    assert notes == ["'work': 0 of 1 windows back\nDid not open: kitty"]


def test_alt_d_deletes_and_shows_the_list_again(flow, session):
    build, layouts, notes = flow
    layouts.save("old", [])
    layouts.save("new", [])
    manager, menu, desktop = build(session.Choice(0, delete=True), None)
    manager.load()
    assert layouts.names() == ["old"] and desktop.reopened == []
    assert len(menu.asked) == 2                                  # the list came back once


def test_load_without_layouts_says_so(flow):
    build, _, notes = flow
    manager, menu, _ = build()
    manager.load()
    assert menu.asked == [] and notes[0].startswith("No saved layouts yet")


def test_unknown_subcommand_prints_usage(session, capsys):
    assert session.main(["x", "dance"]) == 1
    assert "session-manager.py save" in capsys.readouterr().err
