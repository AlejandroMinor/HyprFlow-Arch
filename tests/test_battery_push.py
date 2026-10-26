"""Tests for lib/battery-push.py, on a state file in a temporary folder."""

import io
import json

import pytest

from conftest import load_script

NOW = 1_800_000_000.0


@pytest.fixture
def push():
    return load_script("battery-push.py")


def test_what_the_shortcut_sends_is_kept_with_its_time(push, tmp_path):
    state = tmp_path / "pushed.json"
    text = '{\n  "Alejandro’s Apple Watch" : 67,\n  "iPhone de Alejandro" : 85\n}'
    assert push.main(["add", "-"], state, io.StringIO(text), NOW) == 0
    kept = json.loads(state.read_text())
    assert kept["Alejandro’s Apple Watch"] == {"percent": 67, "charging": False, "at": NOW}
    assert kept["iPhone de Alejandro"]["percent"] == 85


def test_a_push_replaces_only_the_devices_it_names(push, tmp_path):
    state = tmp_path / "pushed.json"
    push.main(["add", "-"], state, io.StringIO('{"iPhone": 85, "iPad": 80}'), NOW)
    push.main(["add", "-"], state, io.StringIO('{"iPhone": 60}'), NOW + 60)
    kept = json.loads(state.read_text())
    assert (kept["iPhone"]["percent"], kept["iPad"]["percent"]) == (60, 80)
    assert kept["iPhone"]["at"] == NOW + 60


def test_a_list_with_charging_and_a_double_braced_one_are_read(push, tmp_path):
    state = tmp_path / "pushed.json"
    text = '[{"name": "iPhone", "percent": 40, "charging": true}]\n{{"Watch": 70}}'
    assert push.main(["add", "-"], state, io.StringIO(text), NOW) == 0
    kept = json.loads(state.read_text())
    assert kept["iPhone"]["charging"] and kept["Watch"]["percent"] == 70


@pytest.mark.parametrize("text", ['not json', '{"iPhone": "lots"}', '{"iPhone": 140}', '[3]'])
def test_a_bad_push_keeps_what_was_there(push, tmp_path, capsys, text):
    state = tmp_path / "pushed.json"
    push.main(["add", "-"], state, io.StringIO('{"iPad": 80}'), NOW)
    assert push.main(["add", "-"], state, io.StringIO(text), NOW) == 1
    assert "bad batteries" in capsys.readouterr().err
    assert list(json.loads(state.read_text())) == ["iPad"]


def test_list_and_clear(push, tmp_path, capsys):
    state = tmp_path / "pushed.json"
    push.main(["add", "-"], state, io.StringIO('{"iPhone": 85}'), NOW)
    push.main(["list"], state, now=NOW + 600)
    assert capsys.readouterr().out.strip() == "85%  iPhone  (10 min ago)"
    push.main(["clear"], state, now=NOW)
    assert json.loads(state.read_text()) == {}
