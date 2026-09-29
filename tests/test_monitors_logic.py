"""Unit tests for the pure parts of lib/monitors.py and its setup wizard;
test_monitors.py drives the whole command end to end."""

import io
import json

import pytest

NZXT = {"name": "DP-2", "description": "NZXT Canvas 27Q", "width": 2560, "height": 1440,
        "refreshRate": 164.998, "scale": 1.0, "disabled": False,
        "availableModes": ["2560x1440@165.00Hz", "2560x1440@60.00Hz", "1920x1080@60.00Hz"]}
AOC = {"name": "HDMI-A-1", "description": "AOC 24B3HM", "width": 1920, "height": 1080,
       "refreshRate": 74.97, "scale": 1.0, "disabled": False,
       "availableModes": ["1920x1080@75.00Hz", "1920x1080@59.94Hz", "1280x720@60.00Hz"]}


def test_number_prints_like_jq(mons):
    assert (mons.number(1), mons.number(1.0), mons.number(1.5)) == ("1", "1.0", "1.5")


def test_signature_is_order_independent(mons):
    assert mons.signature([NZXT, AOC]) == mons.signature([AOC, NZXT]) == "AOC 24B3HM|NZXT Canvas 27Q"


def test_default_profile_puts_the_largest_first_as_primary(mons):
    profile = mons.default_profile([AOC, NZXT])
    assert [(e["description"], e["primary"], e["bar"], e["mode"]) for e in profile] == [
        ("AOC 24B3HM", False, "minimal", "1920x1080@75.00"),
        ("NZXT Canvas 27Q", True, "full", "2560x1440@165.00"),
    ]


def test_logical_width_swaps_for_portrait_and_divides_by_scale(mons):
    assert mons.logical_width({"mode": "1920x1080@60", "scale": 1.0, "transform": 0}) == 1920
    assert mons.logical_width({"mode": "1920x1080@60", "scale": 1.5, "transform": 1}) == 720


def test_mirror_picks_the_largest_shared_resolution_and_closest_rate(mons):
    profile = [{"description": "NZXT Canvas 27Q", "mode": "2560x1440@165", "scale": 1.0, "primary": True},
               {"description": "AOC 24B3HM", "mode": "1920x1080@75", "scale": 1.0, "transform": 1}]
    mirrored = mons.mirrorize(profile, "NZXT Canvas 27Q", [NZXT, AOC])
    assert mirrored[0]["mode"] == "1920x1080@60" and "mirror" not in mirrored[0]
    assert mirrored[1] == {"description": "AOC 24B3HM", "mode": "1920x1080@75", "scale": 1.0,
                           "transform": 0, "primary": False, "mirror": "NZXT Canvas 27Q"}


def test_solo_switches_off_every_other_monitor(mons):
    entry = {"description": "AOC 24B3HM", "mode": "1920x1080@75", "primary": True}
    assert mons.solo_profile([NZXT, AOC], entry) == [
        entry, {"description": "NZXT Canvas 27Q", "disabled": True, "bar": "none"}]


def test_generate_skips_a_sleeping_connector_but_keeps_explicit_offs(mons):
    profile = [{"description": "NZXT Canvas 27Q", "mode": "2560x1440@165", "scale": 1.0, "primary": True, "bar": "full"},
               {"description": "AOC 24B3HM", "mode": "1920x1080@75", "scale": 1.0, "bar": "minimal"}]
    lua, _ = mons.generate(profile, [NZXT, AOC], connected=lambda port: port != "HDMI-A-1")
    assert "HDMI-A-1" not in lua
    profile[1]["disabled"] = True
    lua, _ = mons.generate(profile, [NZXT, AOC], connected=lambda port: port != "HDMI-A-1")
    assert 'hl.monitor({ output = "HDMI-A-1", disabled = true })' in lua


def test_generate_bars_take_the_archetype_and_a_fitting_width(mons):
    template = {"_comment": "x", "full": {"_comment": "y", "height": 48},
                "minimal": {"name": "minimal", "width": 50}}
    profile = [{"description": "NZXT Canvas 27Q", "mode": "2560x1440@165", "scale": 1.0, "primary": True, "bar": "full"},
               {"description": "AOC 24B3HM", "mode": "1920x1080@75", "scale": 1.0, "bar": "minimal"}]
    _, bars = mons.generate(profile, [NZXT, AOC], template)
    assert bars == [{"height": 48, "output": ["DP-2"], "width": 2440},
                    {"name": "minimal", "width": 50, "output": ["HDMI-A-1"]}]


def test_resolution_choices_group_rates_largest_first(mons):
    assert mons.resolution_choices(AOC) == [("1920x1080", ["75", "59.94"]), ("1280x720", ["60"])]


def test_listing_shows_the_current_mode_or_off(mons):
    text = mons.listing([NZXT, dict(AOC, disabled=True)])
    lines = text.splitlines()
    assert "2560x1440@165Hz" in lines[1] and lines[2].split()[-2] == "off"
    assert text.endswith("Use the DESCRIPTION column verbatim in Waybar / profiles.\n")


def test_profiles_save_and_get_by_set(mons, tmp_path):
    profiles = mons.Profiles(tmp_path / "p.json")
    assert profiles.get("a|b") is None
    profiles.save("a|b", [{"description": "a"}])
    profiles.save("c", [])
    assert profiles.get("a|b") == [{"description": "a"}] and profiles.get("c") == []


def test_setup_wizard_builds_and_saves_the_profile(mons, tmp_path, monkeypatch):
    monkeypatch.setattr(mons, "detect", lambda: [NZXT, AOC])
    monkeypatch.setattr(mons, "PROFILES", tmp_path / "profiles.json")
    monkeypatch.setattr(mons, "UNMIRRORED", tmp_path / "unmirrored.json")
    applied = []
    monkeypatch.setattr(mons, "apply", lambda profile=None: applied.append(True))
    answers = "\n".join([
        "",          # NZXT: enable
        "1",         # resolution 2560x1440
        "1",         # fastest refresh
        "0", "", "", # transform, scale, bar full
        "",          # AOC: enable
        "",          # resolution: preferred
        "2",         # 59.94 Hz
        "1", "1.25", "m",   # portrait, scale, minimal bar
        "1 0",       # AOC on the left
        "1",         # NZXT primary
        "n",         # no mirror
    ]) + "\n"
    mons.cmd_setup(mons.Tty(io.StringIO(answers)))
    saved = json.loads((tmp_path / "profiles.json").read_text())["AOC 24B3HM|NZXT Canvas 27Q"]
    assert saved == [
        {"description": "AOC 24B3HM", "mode": "1920x1080@59.94", "scale": 1.25, "transform": 1,
         "primary": False, "bar": "minimal"},
        {"description": "NZXT Canvas 27Q", "mode": "2560x1440@165", "scale": 1.0, "transform": 0,
         "primary": True, "bar": "full"},
    ]
    assert applied == [True]


def test_setup_with_every_monitor_disabled_stops(mons, monkeypatch):
    monkeypatch.setattr(mons, "detect", lambda: [NZXT])
    with pytest.raises(mons.Stop, match="no monitors enabled"):
        mons.cmd_setup(mons.Tty(io.StringIO("n\n")))


@pytest.mark.parametrize("bad", [0, -1, True, float("inf"), 9, "1.5", None])
def test_a_scale_hyprland_cannot_use_is_refused(mons, bad):
    with pytest.raises(ValueError):
        mons.scale_of(bad)
    with pytest.raises(ValueError):
        mons.logical_width({"mode": "1920x1080@60", "scale": bad})


def test_setup_wizard_survives_bad_answers(mons, tmp_path, monkeypatch):
    monkeypatch.setattr(mons, "detect", lambda: [NZXT, AOC])
    monkeypatch.setattr(mons, "PROFILES", tmp_path / "profiles.json")
    monkeypatch.setattr(mons, "UNMIRRORED", tmp_path / "unmirrored.json")
    monkeypatch.setattr(mons, "apply", lambda profile=None: None)
    answers = "\n".join([
        "", "1", "1", "0", "0", "",     # NZXT: scale 0 is refused
        "", "", "1", "0", "true", "",   # AOC: scale true is refused
        "0 5",                          # no monitor 5: the order stays
        "7",                            # no monitor 7: the primary is 0
        "y",                            # mirror, which needs a primary
    ]) + "\n"
    mons.cmd_setup(mons.Tty(io.StringIO(answers)))
    saved = json.loads((tmp_path / "profiles.json").read_text())["AOC 24B3HM|NZXT Canvas 27Q"]
    assert [(e["description"], e["scale"], e["primary"]) for e in saved] == [
        ("NZXT Canvas 27Q", 1.0, True), ("AOC 24B3HM", 1.0, False)]
    assert saved[1]["mirror"] == "NZXT Canvas 27Q"


def test_setup_without_a_terminal_says_so(mons, monkeypatch):
    def no_tty(*a, **k):
        raise OSError("no tty")
    monkeypatch.setattr("builtins.open", no_tty)
    with pytest.raises(mons.Stop, match="from a terminal"):
        mons.cmd_setup()


def test_the_apply_lock_is_per_user(mons):
    assert mons.LOCK.parent == mons.paths.HYPRFLOW_RUNTIME


def test_hyprland_not_answering_is_a_message_not_a_traceback(mons, monkeypatch, capsys):
    def fails():
        raise mons.hyprctl.HyprctlError("hyprctl monitors all: no answer in 5 s")
    monkeypatch.setattr(mons, "detect", fails)
    assert mons.main(["monitors.py", "list"]) == 1
    assert "no answer in 5 s" in capsys.readouterr().err


def test_a_profile_missing_a_field_is_a_message(mons, monkeypatch, capsys):
    def broken():
        raise KeyError("description")
    monkeypatch.setattr(mons, "cmd_list", broken)
    assert mons.main(["monitors.py", "list"]) == 1
    assert "no 'description' field" in capsys.readouterr().err
