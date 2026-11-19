#!/usr/bin/env bash
# shellcheck shell=bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/harness.sh"

test_fedora_detection() {
  uf_detect_all --refresh
  uf_detect_os
  uf_assert_eq "1" "$UF_IS_FEDORA" "Fedora detected from fixture" || return 1
  uf_assert_eq "44" "$UF_DISTRO_VERSION_ID" "version from fixture" || return 1
  uf_assert_contains "Fedora Linux 44" "$UF_DISTRO_PRETTY" "pretty name" || return 1
}

test_gnome_detection_from_binary() {
  uf_detect_all --refresh
  uf_assert_eq "1" "$UF_GNOME_AVAILABLE" "GNOME detected" || return 1
  uf_assert_eq "45.0" "$UF_GNOME_VERSION" "GNOME version" || return 1
  uf_assert_eq "45" "$UF_GNOME_MAJOR" "GNOME major" || return 1
}

test_session_detection() {
  export XDG_SESSION_TYPE=wayland
  uf_detect_all --refresh
  uf_assert_eq "wayland" "$UF_SESSION_TYPE" "Wayland session" || return 1
  export XDG_SESSION_TYPE=x11
  uf_detect_all --refresh
  uf_assert_eq "x11" "$UF_SESSION_TYPE" "X11 session" || return 1
}

test_require_fedora_passes() {
  uf_require_fedora || return 1
}

test_require_fedora_refuses_other_distro() {
  cat >"$UF_TEST_TMP/other-release" <<'EOF'
ID=debian
VERSION_ID=13
PRETTY_NAME="Debian GNU/Linux 13"
EOF
  UF_OS_RELEASE_FILE="$UF_TEST_TMP/other-release" uf_detect_all --refresh
  UF_ALLOW_UNSUPPORTED=0
  uf_assert_fails uf_require_fedora || return 1
  UF_ALLOW_UNSUPPORTED=1
}

test_summary_does_not_crash() {
  uf_detect_all --refresh
  local summary
  summary="$(uf_detect_summary)" || return 1
  uf_assert_contains "Fedora 44" "$summary" "summary contains release" || return 1
}

uf_run_tests \
  test_fedora_detection \
  test_gnome_detection_from_binary \
  test_session_detection \
  test_require_fedora_passes \
  test_require_fedora_refuses_other_distro \
  test_summary_does_not_crash
