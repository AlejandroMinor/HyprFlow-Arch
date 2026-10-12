#!/usr/bin/env python3
"""confirm.py PROMPT OPTION...: asks on the Quickshell panel (rofi when it is
not running) and prints the chosen option; exits 1 when dismissed. For the
Bash scripts; the Python ones ask hyprflow.menu themselves."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hyprflow.menu import QuickshellMenu  # noqa: E402


def main(argv, menu=None):
    if len(argv) < 3:
        print("usage: confirm.py PROMPT OPTION...", file=sys.stderr)
        return 2
    answer = (menu or QuickshellMenu()).confirm(argv[1], argv[2:])
    if answer is None:
        return 1
    print(answer)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
