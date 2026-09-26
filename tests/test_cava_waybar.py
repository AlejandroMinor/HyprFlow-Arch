"""Tests for lib/cava_waybar.py: cava's frames are fed in by hand."""

import re

COLORS = ["#111111", "#222222", "#333333", "#444444"]


def glyphs(text):
    return re.sub(r"<[^>]+>", "", text)


def test_parse_reads_a_raw_ascii_frame(cava):
    assert cava.parse("0 3 7 1 \n") == [0, 3, 7, 1]
    assert cava.parse("\n") == []


def test_every_bar_is_drawn_even_at_zero(cava):
    state = cava.render([0, 5, 0, 7], COLORS)
    assert len(glyphs(state["text"])) == 4
    assert state["class"] == "active"


def test_silence_dims_to_the_baseline(cava):
    state = cava.render([0, 0, 0], COLORS)
    assert state["class"] == "idle"
    assert state["text"].startswith(f"<span alpha='{cava.IDLE_ALPHA}'>")
    assert glyphs(state["text"]) == cava.GLYPHS[0] * 3


def test_higher_bars_take_later_colors(cava):
    text = cava.render([0, 7], COLORS)["text"]
    assert re.findall(r"color='([^']+)'", text) == [COLORS[0], COLORS[-1]]


def test_without_a_palette_it_draws_plain_glyphs(cava):
    assert cava.render([2, 7], [])["text"] == cava.GLYPHS[2] + cava.GLYPHS[7]


def test_palette_comes_from_the_wallust_cava_theme(cava, tmp_path):
    theme = tmp_path / "wallust"
    theme.write_text("[color]\ngradient = 1\ngradient_color_1 = '#aaaaaa'\n"
                     "gradient_color_2 = '#bbbbbb'\n")
    assert cava.palette(theme) == ["#aaaaaa", "#bbbbbb"]
    assert cava.palette(tmp_path / "missing") == []


def test_bar_count_follows_the_cava_config(cava, tmp_path):
    conf = tmp_path / "waybar.conf"
    conf.write_text("[general]\nframerate = 30\nbars = 12\n")
    assert cava.bar_count(conf) == 12
    assert cava.bar_count(tmp_path / "missing") == 10


def test_it_starts_on_a_silent_baseline_of_the_right_width(cava, tmp_path):
    conf = tmp_path / "waybar.conf"
    conf.write_text("bars = 6\n")
    module = cava.CavaWaybar(conf=conf, theme=tmp_path / "none")
    assert module.state()["class"] == "idle"
    assert len(glyphs(module.state()["text"])) == 6


def test_each_frame_from_cava_updates_the_state(cava, monkeypatch, tmp_path):
    frames = iter(["0 0 0\n", "\n", "3 7 1\n"])
    monkeypatch.setattr(cava, "lines", lambda cmd: frames)
    module = cava.CavaWaybar(conf=tmp_path / "none", theme=tmp_path / "none")
    seen = [list(module.heights) for _ in module.events()]
    assert seen == [[0, 0, 0], [3, 7, 1]]   # the empty line is skipped
