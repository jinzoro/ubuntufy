# shellcheck shell=bash
# Entrypoint for sourced execution.

if [ -z "${UF_ROOT:-}" ]; then
  UF_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
  export UF_ROOT
fi
if ! type uf_banner >/dev/null 2>&1; then
  # shellcheck source=lib.sh
  source "${UF_ROOT}/src/lib.sh"
fi

uf_main() {
  local rc=0
  uf_install_traps
  # Command functions return non-zero for expected outcomes (skips, doctor
  # findings, rejected input), so capture the status instead of letting errexit
  # turn every one of them into an "unexpected failure" trap.
  uf_cli "$@" || rc=$?
  uf_lock_release
  return "$rc"
}

# When executed directly, run main.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  uf_main "$@"
  exit $?
fi
