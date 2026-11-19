#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_all_components_have_titles() {
  local component
  for component in "${UF_COMPONENT_ORDER[@]}"; do
    uf_assert_ne "$component" "$(uf_component_title "$component")" "title for ${component}" || return 1
  done
}

test_component_aliases() {
  uf_assert_eq "desktop-icons" "$(uf_component_normalize ding)" "ding alias" || return 1
  uf_assert_eq "desktop-icons" "$(uf_component_normalize desktop_icons)" "underscore alias" || return 1
  uf_assert_eq "default-apps" "$(uf_component_normalize defaults)" "defaults alias" || return 1
  uf_assert_eq "tray" "$(uf_component_normalize appindicator)" "appindicator alias" || return 1
  uf_assert_eq "windows" "$(uf_component_normalize gnome-behavior)" "behaviour alias" || return 1
}

test_component_existence() {
  uf_component_exists theme || return 1
  uf_component_exists plymouth || return 1
  ! uf_component_exists nope || return 1
}

test_profiles_have_expected_components() {
  local minimal full
  minimal="$(uf_profile_components minimal)"
  full="$(uf_profile_components full)"
  uf_assert_contains "theme" "$minimal" "minimal includes theme" || return 1
  uf_assert_contains "wallpaper" "$minimal" "minimal includes wallpaper" || return 1
  uf_assert_contains "default-apps" "$full" "full includes defaults" || return 1
  uf_assert_contains "plymouth" "$full" && return 1
  return 0
}

test_every_profile_component_exists() {
  local profile component
  for profile in full minimal classic dark; do
    while IFS= read -r component; do
      uf_component_exists "$component" || {
        printf 'unknown component %s in %s\n' "$component" "$profile" >&2
        return 1
      }
    done < <(uf_profile_components "$profile")
  done
}

test_custom_profile() {
  uf_conf_set "custom.components" "theme;ding;defaults"
  uf_profile_validate custom || return 1
  uf_assert_eq $'theme\ndesktop-icons\ndefault-apps' "$(uf_profile_components custom)" "custom profile normalises" || return 1
  uf_conf_set "custom.components" "theme;bogus"
  uf_assert_fails uf_profile_validate custom || return 1
}

test_unknown_profile_rejected() {
  uf_assert_fails uf_profile_validate nope || return 1
}

test_full_has_no_opt_in_boot_components() {
  local full
  full="$(uf_profile_components full)"
  uf_assert_fails grep -qx "plymouth" <<<"$full" || return 1
  uf_assert_fails grep -qx "gdm" <<<"$full" || return 1
}

uf_run_tests \
  test_all_components_have_titles \
  test_component_aliases \
  test_component_existence \
  test_profiles_have_expected_components \
  test_every_profile_component_exists \
  test_custom_profile \
  test_unknown_profile_rejected \
  test_full_has_no_opt_in_boot_components
