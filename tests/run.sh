#!/usr/bin/env bash
# Ubuntuify Fedora test runner.
#
# Runs every tests/unit/*.sh and tests/integration/*.sh file in isolation.
# No test touches the real desktop: HOME, XDG directories, GSettings, dconf,
# RPM/DNF and GNOME extensions are sandboxed or mocked.
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd -- "$ROOT"

shopt -s nullglob
files=("tests/unit/"*.sh "tests/integration/"*.sh)
if [ "${#files[@]}" -eq 0 ]; then
  echo "No tests found." >&2
  exit 1
fi

failed_files=0
total=0
failures=0

for file in "${files[@]}"; do
  printf '\n== %s\n' "$file"
  if bash "$file"; then
    :
  else
    failed_files=$((failed_files + 1))
  fi
done

printf '\n== summary\n'
printf '%d test file(s) failed\n' "$failed_files"
[ "$failed_files" -eq 0 ]
