#!/usr/bin/env python3
"""Small JSON state helper for Ubuntuify Fedora.

The bash code never parses or writes JSON itself. This helper keeps the state
file atomic, valid and readable by both humans and scripts.

Commands:
    init FILE
    get FILE dotted.key
    set FILE dotted.key VALUE
    add FILE dotted.key VALUE      # append to a list, de-duplicated
    remove FILE dotted.key VALUE
    has FILE dotted.key VALUE
    delete FILE dotted.key
    list-get FILE dotted.key        # one list item per line
    component-get FILE NAME
    component-set FILE NAME STATUS
    dump FILE
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile

DEFAULT_STATE = {
    "version": None,
    "schema": 1,
    "profile": None,
    "fedora_version": None,
    "gnome_version": None,
    "session": None,
    "installed_packages": [],
    "enabled_extensions": [],
    "managed_extensions": [],
    "components": {},
    "backup": None,
    "wallpaper": None,
    "plymouth": {},
}

_NUMBER = re.compile(r"^-?[0-9]+$")
_FLOAT = re.compile(r"^-?[0-9]+\.[0-9]+$")


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"state: {message}", file=sys.stderr)
    raise SystemExit(2)


def coerce(raw: str):
    """Interpret a CLI value as JSON when it clearly is one."""
    stripped = raw.strip()
    if stripped in {"true", "false", "null"}:
        return json.loads(stripped)
    if _NUMBER.match(stripped):
        return int(stripped)
    if _FLOAT.match(stripped):
        return float(stripped)
    if stripped[:1] in ("[", "{"):
        try:
            return json.loads(stripped)
        except json.JSONDecodeError:
            pass
    return raw


def load(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read {path}: {exc}")
    if not isinstance(data, dict):
        fail(f"{path} does not contain a JSON object")
    return data


def save(path: str, data: dict) -> None:
    directory = os.path.dirname(os.path.abspath(path))
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".state-", suffix=".tmp", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2, sort_keys=True, ensure_ascii=False)
            handle.write("\n")
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def path_parts(key: str) -> list[str]:
    parts = [part for part in key.split(".") if part]
    if not parts:
        fail("empty state key")
    return parts


def get_value(data: dict, key: str):
    current = data
    for part in path_parts(key):
        if not isinstance(current, dict) or part not in current:
            return None
        current = current[part]
    return current


def set_value(data: dict, key: str, value) -> None:
    parts = path_parts(key)
    current = data
    for part in parts[:-1]:
        child = current.get(part)
        if not isinstance(child, dict):
            child = {}
            current[part] = child
        current = child
    current[parts[-1]] = value


def del_value(data: dict, key: str) -> None:
    parts = path_parts(key)
    current = data
    for part in parts[:-1]:
        if not isinstance(current, dict) or part not in current:
            return
        current = current[part]
    if isinstance(current, dict):
        current.pop(parts[-1], None)


def print_value(value) -> None:
    if value is None:
        return
    if isinstance(value, str):
        print(value)
    else:
        print(json.dumps(value, ensure_ascii=False))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Ubuntuify state helper")
    parser.add_argument("command")
    parser.add_argument("file")
    parser.add_argument("key", nargs="?")
    parser.add_argument("value", nargs="?")
    args = parser.parse_args(argv)

    if args.command == "init":
        data = load(args.file)
        for key, default in DEFAULT_STATE.items():
            if key not in data:
                data[key] = default
        save(args.file, data)
        return 0

    data = load(args.file)

    if args.command == "dump":
        print(json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False))
        return 0

    if not args.key:
        fail(f"'{args.command}' requires a key")

    if args.command == "get":
        print_value(get_value(data, args.key))
        return 0

    if args.command == "list-get":
        value = get_value(data, args.key)
        if isinstance(value, list):
            for item in value:
                print(item)
        return 0

    if args.command == "has":
        value = get_value(data, args.key)
        wanted = coerce(args.value or "")
        if isinstance(value, list):
            return 0 if wanted in value else 1
        return 0 if value == wanted else 1

    if args.command == "component-get":
        components = data.get("components")
        if isinstance(components, dict):
            value = components.get(args.key)
            if value is not None:
                print_value(value)
        return 0

    if args.command == "component-set":
        if not args.value:
            fail("component-set requires a status")
        components = data.setdefault("components", {})
        if not isinstance(components, dict):
            components = {}
            data["components"] = components
        components[args.key] = coerce(args.value)
        save(args.file, data)
        return 0

    if args.command == "set":
        if args.value is None:
            fail("set requires a value")
        set_value(data, args.key, coerce(args.value))
        save(args.file, data)
        return 0

    if args.command in {"add", "remove"}:
        if args.value is None:
            fail(f"{args.command} requires a value")
        current = get_value(data, args.key)
        if not isinstance(current, list):
            current = []
        value = coerce(args.value)
        if args.command == "add":
            if value not in current:
                current.append(value)
        else:
            current = [item for item in current if item != value]
        set_value(data, args.key, current)
        save(args.file, data)
        return 0

    if args.command == "delete":
        del_value(data, args.key)
        save(args.file, data)
        return 0

    fail(f"unknown command '{args.command}'")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
