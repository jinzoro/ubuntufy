#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_defaults_load() {
  uf_config_init
  uf_assert_eq "full" "$(uf_conf profile)" "default profile" || return 1
  uf_assert_eq "left" "$(uf_conf dock.position)" "default dock position" || return 1
  uf_assert_eq "48" "$(uf_conf dock.icon_size)" "default dock icon size" || return 1
}

test_user_config_overrides_defaults() {
  mkdir -p "$(dirname -- "$UF_USER_CONFIG")"
  cat >"$UF_USER_CONFIG" <<'EOF'
profile=minimal
dock.position=bottom
dock.icon_size=64
EOF
  uf_config_init
  uf_assert_eq "minimal" "$(uf_conf profile)" "user profile" || return 1
  uf_assert_eq "bottom" "$(uf_conf dock.position)" "user dock position" || return 1
  uf_assert_eq "64" "$(uf_conf dock.icon_size)" "user icon size" || return 1
}

test_invalid_values_fall_back() {
  mkdir -p "$(dirname -- "$UF_USER_CONFIG")"
  cat >"$UF_USER_CONFIG" <<'EOF'
profile=bogus
color_scheme=rainbow
dock.position=diagonal
dock.icon_size=999
EOF
  uf_config_init
  uf_config_validate 2>/dev/null || return 1
  uf_assert_eq "full" "$(uf_conf profile)" "invalid profile falls back" || return 1
  uf_assert_eq "default" "$(uf_conf color_scheme)" "invalid scheme falls back" || return 1
  uf_assert_eq "left" "$(uf_conf dock.position)" "invalid dock position falls back" || return 1
  uf_assert_eq "48" "$(uf_conf dock.icon_size)" "invalid size falls back" || return 1
}

test_conf_int_bounds() {
  uf_conf_set "demo.value" "999"
  uf_assert_eq "10" "$(uf_conf_int demo.value 10 1 100)" "out-of-range int falls back" || return 1
  uf_conf_set "demo.value" "42"
  uf_assert_eq "42" "$(uf_conf_int demo.value 10 1 100)" "valid int is used" || return 1
}

test_quoted_values_are_unquoted() {
  mkdir -p "$(dirname -- "$UF_USER_CONFIG")"
  printf 'profile="classic"\n' >"$UF_USER_CONFIG"
  uf_config_init
  uf_assert_eq "classic" "$(uf_conf profile)" "paired quotes stripped" || return 1
}

uf_run_tests \
  test_defaults_load \
  test_user_config_overrides_defaults \
  test_invalid_values_fall_back \
  test_conf_int_bounds \
  test_quoted_values_are_unquoted
