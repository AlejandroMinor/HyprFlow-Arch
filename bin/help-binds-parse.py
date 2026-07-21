#!/usr/bin/env python3
# help-binds-parse.py — extracts "MODS<TAB>DESCRIPTION<TAB>SUBMAP" from keybindings.lua
#
# `hyprctl binds -j` emits invalid JSON for binds registered via Hyprland's
# native Lua API (dispatcher "__lua"), which is how this whole config is
# set up. So we read keybindings.lua directly instead of asking Hyprland
# for the bind list.

import re
import sys


def split_args(inner):
    depth = 0
    in_str = False
    str_char = ""
    current = []
    args = []
    i = 0
    while i < len(inner):
        c = inner[i]
        if in_str:
            current.append(c)
            if c == str_char and inner[i - 1] != "\\":
                in_str = False
        elif c in "\"'":
            in_str = True
            str_char = c
            current.append(c)
        elif c in "([{":
            depth += 1
            current.append(c)
        elif c in ")]}":
            depth -= 1
            current.append(c)
        elif c == "," and depth == 0:
            args.append("".join(current))
            current = []
        else:
            current.append(c)
        i += 1
    if current:
        args.append("".join(current))
    return [a.strip() for a in args]


def extract_call(text, open_paren_index):
    depth = 0
    i = open_paren_index
    in_str = False
    str_char = ""
    while i < len(text):
        c = text[i]
        if in_str:
            if c == str_char and text[i - 1] != "\\":
                in_str = False
        elif c in "\"'":
            in_str = True
            str_char = c
        elif c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return text[open_paren_index : i + 1], i + 1
        i += 1
    raise ValueError("unbalanced parens")


def key_label(expr):
    expr = expr.replace("..", " ")
    expr = expr.replace('"', "").replace("'", "")
    expr = re.sub(r"\bmainMod\b", "SUPER", expr)
    return re.sub(r"\s+", " ", expr).strip()


def find_submap_spans(text):
    spans = []
    for m in re.finditer(r'hl\.define_submap\(\s*"([^"]+)"', text):
        name = m.group(1)
        open_idx = text.index("(", m.start())
        _, end_idx = extract_call(text, open_idx)
        spans.append((m.start(), end_idx, name))
    return spans


def submap_for(pos, spans):
    for start, end, name in spans:
        if start <= pos < end:
            return name
    return ""


def main():
    path = sys.argv[1]
    with open(path) as f:
        text = f.read()

    submap_spans = find_submap_spans(text)
    results = []
    for m in re.finditer(r"hl\.bind\(", text):
        open_idx = text.index("(", m.start())
        call_text, _ = extract_call(text, open_idx)
        inner = call_text[1:-1]
        args = split_args(inner)
        if len(args) < 2:
            continue
        desc_match = re.search(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', inner)
        if not desc_match:
            continue
        submap = submap_for(m.start(), submap_spans)
        mods = key_label(args[0])
        description = desc_match.group(1)
        results.append((submap, mods, description))

    results.sort(key=lambda r: r[0])
    for submap, mods, description in results:
        print(f"{mods}\t{description}\t{submap}")


if __name__ == "__main__":
    main()
