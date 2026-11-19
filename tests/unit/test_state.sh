#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_state_init_and_get() {
  uf_state_init || return 1
  uf_assert_file "$UF_STATE_FILE" || return 1
  uf_state_set profile full || return 1
  uf_assert_eq "full" "$(uf_state_get profile)" "profile read back" || return 1
}

test_state_lists_deduplicate() {
  uf_state_init || return 1
  uf_state_add managed_extensions "a@b"
  uf_state_add managed_extensions "a@b"
  uf_state_add managed_extensions "c@d"
  uf_assert_eq $'a@b\nc@d' "$(uf_state_list managed_extensions)" "duplicates removed" || return 1
  uf_state_remove managed_extensions "a@b" || return 1
  uf_assert_eq "c@d" "$(uf_state_list managed_extensions)" "entry removed" || return 1
}

test_state_component_status() {
  uf_state_init || return 1
  uf_state_component_set dock configured || return 1
  uf_assert_eq "configured" "$(uf_state_component_get dock)" "component status" || return 1
  uf_state_component_set dock failed || return 1
  uf_assert_eq "failed" "$(uf_state_component_get dock)" "component status replaced" || return 1
}

test_state_missing_file_is_safe() {
  uf_assert_fails uf_state_get profile || return 1
  uf_assert_eq "" "$(uf_state_list managed_extensions)" "missing state lists nothing" || return 1
}

test_state_reset_keeps_backups() {
  uf_state_init || return 1
  uf_state_set profile full || return 1
  mkdir -p "$UF_BACKUP_ROOT/20260101-000000"
  uf_state_reset || return 1
  uf_assert_no_file "$UF_STATE_FILE" || return 1
  uf_assert_dir "$UF_BACKUP_ROOT/20260101-000000" || return 1
}

uf_run_tests \
  test_state_init_and_get \
  test_state_lists_deduplicate \
  test_state_component_status \
  test_state_missing_file_is_safe \
  test_state_reset_keeps_backups
