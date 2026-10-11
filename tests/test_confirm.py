"""Tests for lib/confirm.py, the confirmation the Bash scripts ask through.
A fake menu answers: no panel or rofi opens."""

from conftest import load_script

confirm = load_script("confirm.py")


class FakeMenu:
    def __init__(self, answer):
        self.answer, self.asked = answer, []

    def confirm(self, prompt, options):
        self.asked.append((prompt, options))
        return self.answer


def test_prints_the_chosen_option(capsys):
    menu = FakeMenu("Close 2 window(s)")
    assert confirm.main(["confirm.py", "Close?", "Cancel", "Close 2 window(s)"], menu) == 0
    assert menu.asked == [("Close?", ["Cancel", "Close 2 window(s)"])]
    assert capsys.readouterr().out == "Close 2 window(s)\n"


def test_dismissed_exits_1_and_prints_nothing(capsys):
    assert confirm.main(["confirm.py", "Close?", "Cancel", "Close"], FakeMenu(None)) == 1
    assert capsys.readouterr().out == ""


def test_needs_a_prompt_and_an_option(capsys):
    assert confirm.main(["confirm.py", "Close?"], FakeMenu("x")) == 2
