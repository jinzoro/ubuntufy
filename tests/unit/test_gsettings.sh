#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_missing_schema_is_skipped() {
  uf_gs_set org.example.missing key true "Missing"
  uf_assert_eq "0" "$UF_GS_FAILED" "missing schema must not count as failure" || return 1
  uf_assert_no_file "$UF_APPLIED_SETTINGS" || return 1
}

test_missing_key_is_skipped() {
  uf_gs_set org.gnome.desktop.interface no-such-key true "Missing key"
  uf_assert_eq "0" "$UF_GS_FAILED" "missing key must not count as failure" || return 1
}

test_set_records_original_and_applied() {
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Adwaita'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "GTK theme" || return 1
  uf_assert_eq "'Yaru'" "$(uf_mock_setting_get org.gnome.desktop.interface gtk-theme)" "value written" || return 1
  uf_assert_contains "org.gnome.desktop.interface" "$(cat "$UF_ORIGINAL_SETTINGS")" "original recorded" || return 1
  uf_assert_contains "'Adwaita'" "$(cat "$UF_ORIGINAL_SETTINGS")" "old value recorded" || return 1
  uf_assert_contains "'Yaru'" "$(cat "$UF_APPLIED_SETTINGS")" "applied value recorded" || return 1
}

test_set_is_idempotent() {
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Yaru'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "GTK theme" || return 1
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "GTK theme" || return 1
  uf_assert_no_file "$UF_APPLIED_SETTINGS" || return 1
  uf_assert_no_file "$UF_ORIGINAL_SETTINGS" || return 1
}

test_original_recorded_only_once() {
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Adwaita'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "first"
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Yaru'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru-dark'" "second"
  uf_assert_eq "1" "$(wc -l <"$UF_ORIGINAL_SETTINGS" | tr -d ' ')" "first-seen original kept" || return 1
}

test_enum_value_validated() {
  uf_gs_set org.gnome.desktop.interface color-scheme "'rainbow'" "Bad scheme" || return 1
  uf_assert_fails uf_gs_value_allowed org.gnome.desktop.interface color-scheme "'rainbow'" || return 1
  uf_assert_eq "0" "$UF_GS_FAILED" "invalid enum is skipped, not failed" || return 1
}

test_int_range_validated() {
  uf_assert_ok uf_gs_value_allowed org.gnome.desktop.interface cursor-size "24" || return 1
  uf_assert_fails uf_gs_value_allowed org.gnome.desktop.interface cursor-size "999" || return 1
}

test_restore_originals() {
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Adwaita'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "GTK theme" || return 1
  uf_gs_restore_originals >/dev/null || return 1
  uf_assert_eq "'Adwaita'" "$(uf_mock_setting_get org.gnome.desktop.interface gtk-theme)" "original restored" || return 1
}

test_reset_preserves_user_changes() {
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Adwaita'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "GTK theme" || return 1
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Yaru-purple'"
  uf_gs_reset_managed >/dev/null || return 1
  uf_assert_eq "'Yaru-purple'" "$(uf_mock_setting_get org.gnome.desktop.interface gtk-theme)" "user change preserved" || return 1
}

test_dry_run_writes_nothing() {
  UF_DRY_RUN=1
  uf_mock_setting org.gnome.desktop.interface gtk-theme "'Adwaita'"
  uf_gs_set org.gnome.desktop.interface gtk-theme "'Yaru'" "GTK theme" || return 1
  uf_assert_eq "'Adwaita'" "$(uf_mock_setting_get org.gnome.desktop.interface gtk-theme)" "dry-run must not write" || return 1
  uf_assert_no_file "$UF_APPLIED_SETTINGS" || return 1
  UF_DRY_RUN=0
}

uf_run_tests \
  test_missing_schema_is_skipped \
  test_missing_key_is_skipped \
  test_set_records_original_and_applied \
  test_set_is_idempotent \
  test_original_recorded_only_once \
  test_enum_value_validated \
  test_int_range_validated \
  test_restore_originals \
  test_reset_preserves_user_changes \
  test_dry_run_writes_nothing
