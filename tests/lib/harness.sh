# shellcheck shell=bash
# Minimal test harness: no external dependencies, works on any Fedora.
#
# Each test file is sourced with the library loaded. Tests call `uf_test` to
# register a function, and assertions to check behaviour. The harness isolates
# HOME and XDG directories and puts mock commands first on PATH.

UF_TEST_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
export UF_TEST_ROOT
export UF_ROOT="$UF_TEST_ROOT"

UF_TEST_COUNT=0
UF_TEST_FAILED=0
UF_TEST_CURRENT=""
UF_TEST_TMP=""

# uf_test_sandbox -- create an isolated HOME and reset runtime state.
uf_test_sandbox() {
  UF_TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ubuntuify-test.XXXXXX")"
  export HOME="${UF_TEST_TMP}/home"
  export XDG_DATA_HOME="${HOME}/.local/share"
  export XDG_CONFIG_HOME="${HOME}/.config"
  export XDG_CACHE_HOME="${HOME}/.cache"
  export XDG_STATE_HOME="${HOME}/.local/state"
  mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME"

  # lib.sh computes these from HOME/XDG at source time; recompute per test.
  UF_DATA_HOME="$XDG_DATA_HOME"
  UF_CONFIG_HOME="$XDG_CONFIG_HOME"
  UF_STATE_HOME="${UF_DATA_HOME}/ubuntuify"
  UF_STATE_DIR="${UF_STATE_HOME}/state"
  UF_BACKUP_ROOT="${UF_STATE_HOME}/backups"
  UF_LOG_DIR="${UF_STATE_HOME}/logs"
  UF_CACHE_DIR="${UF_STATE_HOME}/cache"
  UF_WALLPAPER_DIR="${UF_STATE_HOME}/wallpapers"
  UF_USER_CONFIG="${UF_CONFIG_HOME}/ubuntuify/config.conf"
  UF_STATE_FILE="${UF_STATE_DIR}/state.json"
  UF_ORIGINAL_SETTINGS="${UF_STATE_DIR}/original-settings.tsv"
  UF_APPLIED_SETTINGS="${UF_STATE_DIR}/applied-settings.tsv"
  UF_BACKUP_INDEX="${UF_STATE_DIR}/backups.tsv"
  UF_LOCK_FILE="${UF_STATE_HOME}/.lock"
  UF_LOG_FILE=""

  export MOCK_GSETTINGS_FILE="${UF_TEST_TMP}/gsettings.tsv"
  export MOCK_GSETTINGS_SCHEMAS="${UF_TEST_TMP}/gsettings-schemas.txt"
  export MOCK_GSETTINGS_KEYS_DIR="${UF_TEST_ROOT}/tests/fixtures/gsettings-keys"
  export MOCK_GSETTINGS_RANGES_DIR="${UF_TEST_ROOT}/tests/fixtures/gsettings-ranges"
  export MOCK_RPM_INSTALLED="${UF_TEST_TMP}/rpm-installed.txt"
  export MOCK_DNF_LOG="${UF_TEST_TMP}/dnf.log"
  export MOCK_GNOME_EXTENSIONS="${UF_TEST_TMP}/extensions-enabled.txt"
  export MOCK_DCONF_DUMP="${UF_TEST_TMP}/dconf.ini"
  export MOCK_DCONF_LOADED="${UF_TEST_TMP}/dconf-loaded.ini"
  export MOCK_XDG_MIME_LOG="${UF_TEST_TMP}/xdg-mime.log"
  export MOCK_XDG_SETTINGS_LOG="${UF_TEST_TMP}/xdg-settings.log"
  export MOCK_FC_LIST="${UF_TEST_TMP}/fc-list.txt"
  export MOCK_PLYMOUTH_THEME="bgrt"
  export MOCK_GNOME_VERSION="45.0"
  export UF_OS_RELEASE_FILE="${UF_TEST_ROOT}/tests/fixtures/os-release"
  export UF_ALLOW_UNSUPPORTED=1

  : >"$MOCK_GSETTINGS_FILE"
  cp "${UF_TEST_ROOT}/tests/fixtures/gsettings-schemas.txt" "$MOCK_GSETTINGS_SCHEMAS"
  : >"$MOCK_RPM_INSTALLED"
  : >"$MOCK_DNF_LOG"
  : >"$MOCK_GNOME_EXTENSIONS"
  : >"$MOCK_DCONF_DUMP"
  : >"$MOCK_DCONF_LOADED"
  : >"$MOCK_XDG_MIME_LOG"
  : >"$MOCK_XDG_SETTINGS_LOG"
  printf 'Ubuntu\nUbuntu Mono\n' >"$MOCK_FC_LIST"

  # A realistic Fedora GNOME baseline.
  cat >"$MOCK_GSETTINGS_FILE" <<'EOF'
org.gnome.desktop.interface	gtk-theme	'Breeze'
org.gnome.desktop.interface	icon-theme	'Adwaita'
org.gnome.desktop.interface	cursor-theme	'Adwaita'
org.gnome.desktop.interface	color-scheme	'default'
org.gnome.desktop.interface	clock-format	'24h'
org.gnome.desktop.wm.preferences	button-layout	'appmenu:minimize,maximize,close'
org.gnome.desktop.wm.preferences	focus-mode	'click'
org.gnome.shell	favorite-apps	'[]'
org.gnome.shell	enabled-extensions	'[]'
org.gnome.shell	disabled-extensions	'[]'
EOF

  # Reset module state.
  UF_GS_CACHE_LOADED=0
  UF_GS_FAILED=0
  declare -gA UF_CONF=()
  declare -gA UF_CONF_OVERRIDES=()
  UF_CONF_LOADED=0
  UF_ONLINE_EXTENSIONS=ask
  UF_DETECTED=0
  UF_CHANGED_COUNT=0
  UF_WARN_COUNT=0
  UF_SKIP_COUNT=0
  UF_ERROR_COUNT=0
  UF_DRY_RUN=0
  UF_ASSUME_YES=1
  UF_VERBOSE=0
  UF_QUIET=0
  UF_NO_COLOR=1
  UF_NO_BACKUP=0
  UF_FORCE_BACKUP=0
  UF_REMOVE_PACKAGES=0
  UF_CURRENT_COMPONENT="manual"
  UF_OPT_PROFILE=""
  UF_OPT_COMPONENTS=()
  UF_OPT_BACKUP=""
  UF_OPT_COMPONENT=""
  UF_STATUS_COMPONENTS=0
  UF_STATUS_SCORE=0
  declare -gA UF_GS_SCHEMA_CACHE=()
  declare -gA UF_GS_KEY_CACHE=()
  declare -gA UF_GS_RANGE_CACHE=()
}

# uf_test_cleanup
uf_test_cleanup() {
  [ -n "$UF_TEST_TMP" ] && rm -rf -- "$UF_TEST_TMP"
  UF_TEST_TMP=""
}

# uf_test NAME FUNCTION
uf_test() {
  UF_TEST_CURRENT="$1"
  if "$2"; then
    UF_TEST_COUNT=$((UF_TEST_COUNT + 1))
    printf '  ok   %s\n' "$1"
  else
    UF_TEST_COUNT=$((UF_TEST_COUNT + 1))
    UF_TEST_FAILED=$((UF_TEST_FAILED + 1))
    printf '  FAIL %s\n' "$1"
  fi
  uf_test_cleanup
  uf_test_sandbox
}

# Assertions ---------------------------------------------------------------

uf_assert_eq() {
  local expected="$1" actual="$2" message="${3:-values differ}"
  if [ "$expected" != "$actual" ]; then
    printf '       %s\n       expected: %s\n       actual:   %s\n' "$message" "$expected" "$actual" >&2
    return 1
  fi
}

uf_assert_ne() {
  [ "$1" != "$2" ]
}

uf_assert_contains() {
  local needle="$1" haystack="$2" message="${3:-substring not found}"
  case "$haystack" in
    *"$needle"*) return 0 ;;
    *)
      printf '       %s\n       expected to contain: %s\n       actual: %s\n' "$message" "$needle" "$haystack" >&2
      return 1
      ;;
  esac
}

uf_assert_file() {
  [ -f "$1" ] || {
    printf '       expected file: %s\n' "$1" >&2
    return 1
  }
}

uf_assert_no_file() {
  [ ! -e "$1" ] || {
    printf '       unexpected file: %s\n' "$1" >&2
    return 1
  }
}

uf_assert_dir() {
  [ -d "$1" ] || {
    printf '       expected directory: %s\n' "$1" >&2
    return 1
  }
}

uf_assert_ok() {
  "$@"
}

uf_assert_fails() {
  # Run in a subshell so an expected uf_die/exit cannot end the test run.
  if ( "$@" ); then
    printf '       expected failure: %s\n' "$*" >&2
    return 1
  fi
}

# uf_mock_install_packages -- mark RPMs as installed for package checks.
uf_mock_install_packages() {
  printf '%s\n' "$@" >>"$MOCK_RPM_INSTALLED"
}

# uf_mock_schema -- add a schema to the mock.
uf_mock_schema() {
  printf '%s\n' "$1" >>"$MOCK_GSETTINGS_SCHEMAS"
}

# uf_mock_setting -- seed/replace a current value in the mock database.
uf_mock_setting() {
  gsettings set "$1" "$2" "$3"
}

# uf_mock_setting_get -- read a mock value.
uf_mock_setting_get() {
  gsettings get "$1" "$2"
}

# uf_run_tests -- run all registered tests in the current file.
uf_run_tests() {
  local tests=("$@")
  local fn
  for fn in "${tests[@]}"; do
    uf_test "$fn" "$fn"
  done
  printf '\n%d test(s), %d failure(s)\n' "$UF_TEST_COUNT" "$UF_TEST_FAILED"
  [ "$UF_TEST_FAILED" -eq 0 ]
}

# Prepare an isolated HOME before the library computes its XDG paths.
uf_test_sandbox
# Never leave a sandbox behind, including after a failing test file.
trap uf_test_cleanup EXIT
export PATH="${UF_TEST_ROOT}/tests/mocks:${PATH}"
# shellcheck source=../../src/lib.sh
source "${UF_TEST_ROOT}/src/lib.sh"
