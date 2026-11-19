#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

run_cli() {
  HOME="$HOME" \
    XDG_DATA_HOME="$XDG_DATA_HOME" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    UF_OS_RELEASE_FILE="$UF_OS_RELEASE_FILE" \
    UF_ALLOW_UNSUPPORTED=1 \
    UF_NO_COLOR=1 \
    PATH="$PATH" \
    bash "$UF_TEST_ROOT/bin/ubuntuify" "$@" 2>&1
}

test_version() {
  local out
  out="$(run_cli version)" || return 1
  uf_assert_contains "Ubuntuify Fedora" "$out" "name" || return 1
  uf_assert_contains "1.0.0" "$out" "version" || return 1
}

test_help_lists_commands() {
  local out
  out="$(run_cli help)" || return 1
  uf_assert_contains "install" "$out" "install command" || return 1
  uf_assert_contains "uninstall" "$out" "uninstall command" || return 1
  uf_assert_contains "doctor" "$out" "doctor command" || return 1
}

test_help_for_command() {
  local out
  out="$(run_cli help restore)" || return 1
  uf_assert_contains "--backup" "$out" "restore options" || return 1
}

test_install_help() {
  local out
  out="$(run_cli install --help)" || return 1
  uf_assert_contains "--profile" "$out" "install profile option" || return 1
  uf_assert_contains "--dry-run" "$out" "dry run option" || return 1
}

test_components_command() {
  local out
  out="$(run_cli components)" || return 1
  uf_assert_contains "desktop-icons" "$out" "component listed" || return 1
  uf_assert_contains "Tiling Assistant" "$out" "component title" || return 1
}

test_unknown_command_fails() {
  uf_assert_fails run_cli does-not-exist || return 1
}

test_unknown_option_fails() {
  uf_assert_fails run_cli status --bogus || return 1
}

test_unexpected_argument_fails() {
  uf_assert_fails run_cli version extra || return 1
}

test_status_without_state() {
  local out
  out="$(run_cli status)" || return 1
  uf_assert_contains "Not installed" "$out" "uninstalled state" || return 1
}

test_status_components() {
  local out
  out="$(run_cli status --components)" || return 1
  uf_assert_contains "Theme" "$out" "component table" || return 1
  uf_assert_contains "Plymouth" "$out" "boot component row" || return 1
}

test_status_score() {
  local out
  out="$(run_cli status --score)" || return 1
  uf_assert_contains "Ubuntu Experience" "$out" "score header" || return 1
  uf_assert_contains "Overall" "$out" "overall score" || return 1
}

test_config_sample() {
  local out
  out="$(run_cli config --sample)" || return 1
  uf_assert_contains "profile=full" "$out" "sample profile" || return 1
  uf_assert_contains "wallpaper.mode" "$out" "sample wallpaper" || return 1
}

test_dry_run_install() {
  mkdir -p "$HOME/.themes/Yaru/gtk-3.0" "$HOME/.themes/Yaru/gnome-shell"
  mkdir -p "$HOME/.icons/Yaru/cursors"
  printf '[Icon Theme]\nName=Yaru\n' >"$HOME/.icons/Yaru/index.theme"
  local out
  out="$(run_cli install --profile minimal --dry-run)" || return 1
  uf_assert_contains "Dry run" "$out" "dry run header" || return 1
  uf_assert_contains "No changes were made" "$out" "no-op promise" || return 1
  uf_assert_no_file "$UF_STATE_FILE" || return 1
}

test_bad_profile_is_rejected() {
  uf_assert_fails run_cli install --profile nonsense || return 1
}

test_doctor_runs() {
  local out
  out="$(run_cli doctor)" || return 1
  uf_assert_contains "Ubuntuify Doctor" "$out" "doctor header" || return 1
  uf_assert_contains "Fedora detected" "$out" "fedora check" || return 1
}

uf_run_tests \
  test_version \
  test_help_lists_commands \
  test_help_for_command \
  test_install_help \
  test_components_command \
  test_unknown_command_fails \
  test_unknown_option_fails \
  test_unexpected_argument_fails \
  test_status_without_state \
  test_status_components \
  test_status_score \
  test_config_sample \
  test_dry_run_install \
  test_bad_profile_is_rejected \
  test_doctor_runs
