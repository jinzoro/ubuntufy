#!/usr/bin/env python3
"""Validate extensions.gnome.org metadata before anything is installed.

The network fetch is performed by bash with curl and HTTPS only. This helper
never downloads: it validates the API response and the extension ZIP so that
the shell only installs the exact extension that was requested.

Usage:
    ego_helper.py download-path JSON_FILE UUID
    ego_helper.py verify-zip ZIP_FILE UUID
"""

from __future__ import annotations

import json
import sys
import zipfile


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"ego: {message}", file=sys.stderr)
    raise SystemExit(1)


def download_path(json_file: str, uuid: str) -> str:
    try:
        with open(json_file, encoding="utf-8") as handle:
            info = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read extension metadata: {exc}")
    if not isinstance(info, dict):
        fail("extension metadata is not an object")
    if info.get("uuid") != uuid:
        fail(f"requested {uuid!r} but the API returned {info.get('uuid')!r}")
    path = info.get("download_url")
    if not isinstance(path, str):
        fail("API response has no download_url")
    if not path.startswith("/download-extension/") or not path.endswith(".shell-extension.zip"):
        fail(f"unexpected download path: {path!r}")
    return path


def verify_zip(zip_file: str, uuid: str) -> None:
    try:
        with zipfile.ZipFile(zip_file) as archive:
            names = archive.namelist()
            if "metadata.json" not in names:
                fail("archive has no metadata.json")
            info = json.loads(archive.read("metadata.json").decode("utf-8"))
    except (OSError, zipfile.BadZipFile, UnicodeDecodeError, json.JSONDecodeError) as exc:
        fail(f"invalid extension archive: {exc}")
    if info.get("uuid") != uuid:
        fail(f"archive uuid {info.get('uuid')!r} does not match {uuid!r}")
    shell_versions = info.get("shell-version")
    if isinstance(shell_versions, list) and not shell_versions:
        fail("archive does not declare shell-version support")
    print("ok")


def shell_compatible(metadata_file: str, major: str) -> None:
    try:
        with open(metadata_file, encoding="utf-8") as handle:
            info = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"cannot read extension metadata: {exc}")
    versions = info.get("shell-version")
    if not isinstance(versions, list) or not versions:
        print("unknown")
        return
    normalized = {str(item).split(".")[0] for item in versions}
    print("yes" if major in normalized else "no")


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    command = argv[0]
    if command == "shell-compatible":
        if len(argv) != 3:
            print(__doc__, file=sys.stderr)
            return 2
        shell_compatible(argv[1], argv[2])
        return 0
    path, uuid = argv[1], argv[2]
    if command == "download-path":
        print(download_path(path, uuid))
        return 0
    if command == "verify-zip":
        verify_zip(path, uuid)
        return 0
    print(f"ego: unknown command {command}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
