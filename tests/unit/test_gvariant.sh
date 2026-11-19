#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

GV="$UF_SRC/core/gvariant.py"

test_list_get() {
  local out
  out="$(python3 "$GV" list-get "['a', 'b']")" || return 1
  uf_assert_eq $'a\nb' "$out" "parse string array" || return 1
  out="$(python3 "$GV" list-get "[]")" || return 1
  uf_assert_eq "" "$out" "parse empty array" || return 1
}

test_list_add() {
  local out
  out="$(python3 "$GV" list-add "['a']" "b")" || return 1
  uf_assert_eq "['a', 'b']" "$out" "append" || return 1
  out="$(python3 "$GV" list-add "['a', 'b']" "a")" || return 1
  uf_assert_eq "['a', 'b']" "$out" "no duplicate" || return 1
  out="$(python3 "$GV" list-add "[]" "x")" || return 1
  uf_assert_eq "['x']" "$out" "add to empty" || return 1
}

test_list_remove() {
  local out
  out="$(python3 "$GV" list-remove "['a', 'b']" "a")" || return 1
  uf_assert_eq "['b']" "$out" "remove" || return 1
  out="$(python3 "$GV" list-remove "[]" "a")" || return 1
  uf_assert_eq "[]" "$out" "remove from empty" || return 1
}

test_list_has() {
  python3 "$GV" list-has "['a', 'b']" "b" || return 1
  ! python3 "$GV" list-has "['a']" "b" || return 1
  python3 "$GV" list-has "['a']" "a" || return 1
}

uf_run_tests \
  test_list_get \
  test_list_add \
  test_list_remove \
  test_list_has
