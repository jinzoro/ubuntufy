#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_split_list() {
  local out
  out="$(uf_split_list ';' 'a;b;;c;')"
  uf_assert_eq $'a\nb\nc' "$out" "split should drop empty elements" || return 1
}

test_list_add_unique() {
  local out
  out="$(uf_list_add_unique 'a;b' 'b')"
  uf_assert_eq 'a;b' "$out" "duplicates must not be added" || return 1
  out="$(uf_list_add_unique 'a;b' 'c')"
  uf_assert_eq 'a;b;c' "$out" "new item should be appended" || return 1
  out="$(uf_list_add_unique '' 'x')"
  uf_assert_eq 'x' "$out" "empty list should become the item" || return 1
}

test_validate_int() {
  uf_validate_int 48 16 128 || return 1
  uf_validate_int -1 -4 4 || return 1
  ! uf_validate_int 200 16 128 || return 1
  ! uf_validate_int abc 1 5 || return 1
  ! uf_validate_int '' 1 5 || return 1
}

test_bool_normalisation() {
  local value
  for value in 1 true TRUE yes on enabled; do
    uf_is_true "$value" || return 1
  done
  for value in 0 false no off disabled ""; do
    ! uf_is_true "$value" || return 1
  done
}

test_safe_remove_tree_guard() {
  mkdir -p "$HOME/keep"
  uf_assert_fails uf_safe_remove_tree "$HOME/keep" || return 1
  uf_assert_dir "$HOME/keep" || return 1
  mkdir -p "$UF_STATE_HOME/tmpdir"
  uf_safe_remove_tree "$UF_STATE_HOME/tmpdir" || return 1
  uf_assert_no_file "$UF_STATE_HOME/tmpdir" || return 1
}

uf_run_tests \
  test_split_list \
  test_list_add_unique \
  test_validate_int \
  test_bool_normalisation \
  test_safe_remove_tree_guard
