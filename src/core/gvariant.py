#!/usr/bin/env python3
"""GVariant list helpers.

GSettings stores string arrays as GVariant text such as `['a', 'b']` or
`@as []`. Bash should not parse that by hand, so this helper does it safely
with ast.literal_eval (no evaluation of arbitrary code).

Usage:
    gvariant.py list-get   "<gvariant>"        # one item per line
    gvariant.py list-add   "<gvariant>" ITEM   # print updated array
    gvariant.py list-remove "<gvariant>" ITEM
    gvariant.py list-has   "<gvariant>" ITEM   # exit 0/1
"""

from __future__ import annotations

import ast
import re
import sys

_SAFE_ITEM = re.compile(r"^[A-Za-z0-9@._:+~/=-]+$")


def parse(raw: str) -> list[str]:
    text = raw.strip()
    if not text:
        return []
    for prefix in ("@as ", "@s ", "@a{sv} "):
        if text.startswith(prefix):
            text = text[len(prefix) :]
    if text in ("[]", "@as []"):
        return []
    try:
        value = ast.literal_eval(text)
    except (ValueError, SyntaxError):
        print(f"gvariant: cannot parse array: {raw!r}", file=sys.stderr)
        raise SystemExit(2)
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, (list, tuple)) or not all(isinstance(item, str) for item in value):
        print(f"gvariant: expected a list of strings: {raw!r}", file=sys.stderr)
        raise SystemExit(2)
    return list(value)


def format_list(items: list[str]) -> str:
    return "[" + ", ".join("'" + item.replace("\\", "\\\\").replace("'", "\\'") + "'" for item in items) + "]"


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    command, raw = argv[0], argv[1]
    items = parse(raw)

    if command == "list-get":
        for item in items:
            print(item)
        return 0

    if len(argv) < 3:
        print(f"gvariant: {command} requires an item", file=sys.stderr)
        return 2
    item = argv[2]
    if not _SAFE_ITEM.match(item):
        print(f"gvariant: refusing suspicious item {item!r}", file=sys.stderr)
        return 2

    if command == "list-has":
        return 0 if item in items else 1

    if command == "list-add":
        if item not in items:
            items.append(item)
        print(format_list(items))
        return 0

    if command == "list-remove":
        items = [existing for existing in items if existing != item]
        print(format_list(items))
        return 0

    print(f"gvariant: unknown command {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
