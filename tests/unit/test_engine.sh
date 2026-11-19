#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

uf_test_make_themes() {
  mkdir -p "$HOME/.themes/Yaru/gtk-3.0" "$HOME/.themes/Yaru-dark/gtk-3.0"
  mkdir -p "$HOME/.themes/Yaru/gnome-shell" "$HOME/.themes/Yaru-dark/gnome-shell"
  mkdir -p "$HOME/.icons/Yaru/cursors" "$HOME/.icons/Yaru-dark/cursors"
  printf '[Icon Theme]\nName=Yaru\n' >"$HOME/.icons/Yaru/index.theme"
  printf '[Icon Theme]\nName=Yaru-dark\n' >"$HOME/.icons/Yaru-dark/index.theme"
}

test_resolve_components_from_profile() {
  local out
  out="$(uf_resolve_components minimal)" || return 1
  uf_assert_contains "theme" "$out" "profile expansion" || return 1
}

test_resolve_explicit_components_normalised() {
  UF_OPT_COMPONENTS=(ding tray)
  local out
  out="$(uf_resolve_components full)" || return 1
  uf_assert_eq $'desktop-icons\ntray' "$out" "explicit components" || return 1
}

test_resolve_unknown_component_fails() {
  UF_OPT_COMPONENTS=(bogus)
  uf_assert_fails uf_resolve_components full || return 1
}

test_dry_run_makes_no_changes() {
  uf_test_make_themes
  UF_DRY_RUN=1
  UF_OPT_PROFILE=minimal
  UF_OPT_COMPONENTS=()
  uf_install >/dev/null 2>&1 || return 1
  uf_assert_no_file "$UF_STATE_FILE" || return 1
  uf_assert_no_file "$UF_APPLIED_SETTINGS" || return 1
  [ ! -s "$MOCK_DCONF_LOADED" ] || return 1
  uf_assert_fails grep -qE 'install|makecache|remove' "$MOCK_DNF_LOG" || return 1
  UF_DRY_RUN=0
}

test_dry_run_install_outputs_plan() {
  uf_test_make_themes
  UF_DRY_RUN=1
  UF_OPT_PROFILE=minimal
  UF_OPT_COMPONENTS=()
  local out
  out="$(uf_install 2>&1)" || return 1
  uf_assert_contains "Dry run" "$out" "plan header" || return 1
  uf_assert_contains "No changes were made" "$out" "explicit no-op" || return 1
  UF_DRY_RUN=0
}

test_custom_explicit_components_can_be_dry_run() {
  uf_test_make_themes
  UF_DRY_RUN=1
  UF_OPT_PROFILE=custom
  UF_OPT_COMPONENTS=(theme icons)
  local out
  out="$(uf_install 2>&1)" || return 1
  uf_assert_contains "Yaru theme" "$out" "custom explicit component plan" || return 1
  UF_DRY_RUN=0
  UF_OPT_COMPONENTS=()
}

test_update_custom_uses_saved_components() {
  uf_state_init
  uf_state_set profile custom
  uf_state_set custom_components "theme;icons"
  UF_DRY_RUN=1
  local out
  out="$(uf_update 2>&1)" || return 1
  uf_assert_contains "Yaru theme" "$out" "saved custom component plan" || return 1
  UF_DRY_RUN=0
}

test_install_prepare_backup_reuses_same_profile() {
  uf_state_init
  uf_state_set profile full
  uf_backup_create "install" >/dev/null 2>&1 || return 1
  local first="$UF_BACKUP_ID"
  uf_install_prepare_backup full || return 1
  uf_assert_eq "$first" "$UF_BACKUP_ID" "existing backup reused" || return 1
  uf_assert_eq "1" "$(uf_backup_list | wc -l | tr -d ' ')" "no extra backup" || return 1
}

test_install_prepare_backup_new_profile() {
  uf_state_init
  uf_state_set profile full
  uf_backup_create "install" >/dev/null 2>&1 || return 1
  local first="$UF_BACKUP_ID"
  uf_install_prepare_backup minimal || return 1
  uf_assert_ne "$first" "$UF_BACKUP_ID" "new profile gets a new backup" || return 1
}

test_uninstall_without_state_is_safe() {
  uf_uninstall >/dev/null 2>&1 || return 1
}

test_restore_unknown_component_fails() {
  uf_assert_fails uf_restore_component bogus || return 1
}

uf_run_tests \
  test_resolve_components_from_profile \
  test_resolve_explicit_components_normalised \
  test_resolve_unknown_component_fails \
  test_dry_run_makes_no_changes \
  test_dry_run_install_outputs_plan \
  test_custom_explicit_components_can_be_dry_run \
  test_update_custom_uses_saved_components \
  test_install_prepare_backup_reuses_same_profile \
  test_install_prepare_backup_new_profile \
  test_uninstall_without_state_is_safe \
  test_restore_unknown_component_fails
