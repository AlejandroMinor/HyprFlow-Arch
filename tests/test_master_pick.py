"""Tests for the pure parts of lib/master-pick.py: labels and their size.
The overlay itself is GTK and is not driven here."""

import pytest


def test_letters_are_unique_and_typeable_on_es_us(pick):
    assert len(set(pick.LETTER_LABELS)) == len(pick.LETTER_LABELS) == 26
    assert all(c.isalpha() and c.islower() for c in pick.LETTER_LABELS)


def test_master_is_always_f_on_the_home_row(pick):
    assert pick.LETTER_LABELS[:9] == list("fjdksl ahg".replace(" ", ""))


@pytest.mark.parametrize("index, label", [(0, "1"), (1, "2"), (8, "9"), (9, "0")])
def test_digit_labels(pick, index, label):
    assert pick.digit_label(index) == label


@pytest.mark.parametrize("argv, mode", [
    ([], "letters"), (["--labels=numbers"], "numbers"), (["--labels=emoji"], "letters")])
def test_labels_mode(pick, argv, mode):
    assert pick.parse_labels_mode(argv) == mode


@pytest.mark.parametrize("size, scale", [
    ([700, 1400], 1.0), ([200, 200], 0.5), ([2560, 1440], 1.3), ([1050, 900], 900 / 700)])
def test_label_scale_follows_the_smaller_side_within_limits(pick, size, scale):
    assert pick.label_scale({"size": size}) == pytest.approx(scale)


def test_label_css_scales_font_padding_and_radius(pick):
    css = pick.label_css(0.5)
    assert "font-size: 32px" in css and "padding: 5px 16px" in css and "border-radius: 7px" in css


def test_keys_map_to_digits_and_letters(pick):
    Gdk = pick.Gdk
    assert pick.keyval_to_digit(Gdk.KEY_7) == 7
    assert pick.keyval_to_digit(Gdk.KEY_KP_3) == 3
    assert pick.keyval_to_digit(Gdk.KEY_a) is None
    assert pick.keyval_to_letter(Gdk.KEY_F) == "f"
    assert pick.keyval_to_letter(Gdk.KEY_5) is None
