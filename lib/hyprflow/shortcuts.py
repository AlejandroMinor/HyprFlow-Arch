"""What an iOS Shortcut sends over SSH, as JSON values.

A Shortcut's text is rarely clean JSON: a language model wraps it in a
```json fence, dictionaries come one after another (a Repeat joining one per
item) and each in an extra pair of braces ({{"title": …}}), and notes keep
their raw new lines. read_json() takes all of that; calendar-events.py and
battery-push.py read their stdin through it.
"""
import json


def unfenced(text):
    """TEXT without the ```json … ``` a language model wraps its JSON in."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        text = text.rsplit("```", 1)[0]
    return text


def read_json(text):
    """Every value in TEXT, in order: one, a list (its items), or several in
    a row. ValueError when there is none or it is not JSON."""
    # strict=False: notes keep their raw new lines, which strict JSON refuses.
    decoder, found = json.JSONDecoder(strict=False), []
    text = unfenced(text)
    while text:
        # The Shortcut wraps each dictionary in one more pair: {{"title": …}}.
        wrapped = text.startswith("{{")
        value, end = decoder.raw_decode(text, 1 if wrapped else 0)
        if wrapped:
            end = text.index("}", end) + 1
        found += value if isinstance(value, list) else [value]
        text = text[end:].lstrip(", \r\n\t ")
    if not found:
        raise ValueError("nothing in it")
    return found
