#!/usr/bin/env python3
# help-binds-parse.py — extracts "MODS<TAB>DESCRIPTION<TAB>SUBMAP" from keybindings.lua
#
# `hyprctl binds -j` emits invalid JSON for binds registered via Hyprland's
# native Lua API (dispatcher "__lua"), which is how this whole config is
# set up. So we read keybindings.lua directly instead of asking Hyprland
# for the bind list.

import re
import sys


def scan(text, start=0):
    """Yields (index, char) for every character of Lua source from `start`
    that sits outside a string literal. A string is skipped whole, escapes
    included ("a\\" ends at its second quote), so a quote, comma or bracket
    inside one never counts. The one place that knows what a string is."""
    i = start
    while i < len(text):
        c = text[i]
        if c in "\"'":
            i += 1
            while i < len(text) and text[i] != c:
                i += 2 if text[i] == "\\" else 1
        else:
            yield i, c
        i += 1


def split_args(inner):
    """The top level arguments of a call's inside, split on its commas."""
    depth, start, args = 0, 0, []
    for i, c in scan(inner):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            args.append(inner[start:i])
            start = i + 1
    if inner[start:]:
        args.append(inner[start:])
    return [a.strip() for a in args]


def extract_call(text, open_paren_index):
    """The call's "( ... )" from its opening paren, and the index after it;
    ValueError when it never closes (a config mid edit)."""
    depth = 0
    for i, c in scan(text, open_paren_index):
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren_index : i + 1], i + 1
    raise ValueError("unbalanced parens")


def calls(text, pattern):
    """(match, call text) for each call of `pattern`. One left unclosed is
    skipped, so a typo loses that line only, not the whole list."""
    for m in re.finditer(pattern, text):
        try:
            call_text, end = extract_call(text, text.index("(", m.start()))
        except ValueError:
            continue
        yield m, call_text, end


FOR_LOOP = re.compile(r"for\s+(\w+)\s*=\s*(-?\d+)\s*,\s*(-?\d+)")


def loop_bounds(text, pos, expr):
    """(variable, first, last) of the numeric `for` loop that produced `expr`.

    A key concatenated inside a loop names a *range* and the number is nowhere
    in the text. Reading the bounds off the loop means a different range needs
    no change here."""
    trailing = re.search(r"(\w+)\s*$", expr.strip())
    if not trailing:
        return None
    var = trailing.group(1)
    loops = [m for m in FOR_LOOP.finditer(text, 0, pos) if m.group(1) == var]
    if not loops:
        return None
    return var, loops[-1].group(2), loops[-1].group(3)


def key_label(expr, loop=None):
    if loop:
        var, first, last = loop
        expr = re.sub(rf"\b{re.escape(var)}\b\s*$", f"{first}-{last}", expr.strip())
    expr = expr.replace("..", " ")
    expr = expr.replace('"', "").replace("'", "")
    expr = re.sub(r"\bmainMod\b", "SUPER", expr)
    return re.sub(r"\s+", " ", expr).strip()


def find_submap_spans(text):
    spans = []
    for m, _, end_idx in calls(text, r'hl\.define_submap\(\s*"([^"]+)"'):
        spans.append((m.start(), end_idx, m.group(1)))
    return spans


def submap_for(pos, spans):
    for start, end, name in spans:
        if start <= pos < end:
            return name
    return ""


GESTURE_LABELS = {
    "up": "swipe up",
    "down": "swipe down",
    "left": "swipe left",
    "right": "swipe right",
    "horizontal": "swipe left/right",
    "vertical": "swipe up/down",
    "pinchin": "pinch in",
    "pinchout": "pinch out",
    "pinch": "pinch",
}


def parse_gestures(text):
    """hl.gesture calls -> ("", "N fingers <motion>", description).

    Gestures have no submap, so that column stays empty and they sort first.
    """
    results = []
    for _, call_text, _ in calls(text, r"hl\.gesture\("):
        inner = call_text[1:-1]

        desc = re.search(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', inner)
        fingers = re.search(r"fingers\s*=\s*(\d+)", inner)
        direction = re.search(r'direction\s*=\s*"(\w+)"', inner)
        if not (desc and fingers and direction):
            continue

        motion = GESTURE_LABELS.get(direction.group(1), direction.group(1))
        results.append(("", f"{fingers.group(1)} fingers {motion}", desc.group(1)))
    return results


def parse_binds(text):
    submap_spans = find_submap_spans(text)
    results = []
    for m, call_text, _ in calls(text, r"hl\.bind\("):
        inner = call_text[1:-1]
        args = split_args(inner)
        if len(args) < 2:
            continue
        desc_match = re.search(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', inner)
        if not desc_match:
            continue
        submap = submap_for(m.start(), submap_spans)
        label = key_label(args[0], loop_bounds(text, m.start(), args[0]))
        results.append((submap, label, desc_match.group(1)))
    return results


def main():
    # Takes any number of files and runs both extractors over each: a file
    # without hl.bind or without hl.gesture simply yields nothing for it.
    results = []
    for path in sys.argv[1:]:
        with open(path) as f:
            text = f.read()
        results.extend(parse_binds(text))
        results.extend(parse_gestures(text))

    results.sort(key=lambda r: r[0])
    for submap, mods, description in results:
        print(f"{mods}\t{description}\t{submap}")


if __name__ == "__main__":
    main()
