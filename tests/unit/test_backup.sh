#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_backup_creates_complete_metadata() {
  uf_state_init
  uf_backup_create "unit test" || return 1
  local dir="${UF_BACKUP_ROOT}/${UF_BACKUP_ID}"
  uf_assert_dir "$dir" || return 1
  uf_assert_file "${dir}/meta.txt" || return 1
  uf_assert_file "${dir}/dconf.dump" || return 1
  uf_assert_file "${dir}/checksums.sha256" || return 1
  uf_assert_contains "reason=unit test" "$(cat "${dir}/meta.txt")" "reason recorded" || return 1
  uf_assert_eq "$UF_BACKUP_ID" "$(uf_backup_latest)" "latest backup" || return 1
}

test_backups_never_overwrite() {
  uf_state_init
  uf_backup_create "first" || return 1
  local first="$UF_BACKUP_ID"
  uf_backup_create "second" || return 1
  local second="$UF_BACKUP_ID"
  uf_assert_ne "$first" "$second" "ids differ" || return 1
  uf_assert_dir "${UF_BACKUP_ROOT}/${first}" || return 1
  uf_assert_dir "${UF_BACKUP_ROOT}/${second}" || return 1
  uf_assert_contains "reason=first" "$(cat "${UF_BACKUP_ROOT}/${first}/meta.txt")" "first intact" || return 1
}

test_backup_ids_are_safe() {
  uf_state_init
  uf_backup_create "test" || return 1
  [[ $UF_BACKUP_ID =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  uf_assert_fails uf_backup_exists "../etc" || return 1
}

test_backup_verify_detects_empty_backup() {
  uf_state_init
  mkdir -p "${UF_BACKUP_ROOT}/empty"
  : >"${UF_BACKUP_ROOT}/empty/meta.txt"
  uf_assert_fails uf_backup_verify empty || return 1
}

test_backup_prune_keeps_newest() {
  uf_conf_set "backup.keep" "2"
  uf_state_init
  mkdir -p "$UF_BACKUP_ROOT/20200101-000000" "$UF_BACKUP_ROOT/20200102-000000" "$UF_BACKUP_ROOT/20200103-000000"
  for id in 20200101-000000 20200102-000000 20200103-000000; do
    printf 'id=%s\nreason=old\n' "$id" >"${UF_BACKUP_ROOT}/${id}/meta.txt"
  done
  uf_backup_prune || return 1
  uf_assert_no_file "$UF_BACKUP_ROOT/20200101-000000" || return 1
  uf_assert_dir "$UF_BACKUP_ROOT/20200103-000000" || return 1
}

uf_run_tests \
  test_backup_creates_complete_metadata \
  test_backups_never_overwrite \
  test_backup_ids_are_safe \
  test_backup_verify_detects_empty_backup \
  test_backup_prune_keeps_newest
