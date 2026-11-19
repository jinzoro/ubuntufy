# shellcheck shell=bash
# Error handling, traps and recovery hints.

UF_ERR_TRAP_ACTIVE="${UF_ERR_TRAP_ACTIVE:-0}"

# uf_die MESSAGE -- print an error and exit.
uf_die() {
  uf_error "$*"
  exit 1
}

# uf_on_err STATUS LINE COMMAND -- ERR trap. Unexpected failures should never
# leave the user without an explanation or a way back.
uf_on_err() {
  local status="${1:-1}" line="${2:-?}" command="${3:-unknown}"
  if [ "${UF_ERR_TRAP_ACTIVE:-0}" -eq 1 ]; then
    exit "$status"
  fi
  UF_ERR_TRAP_ACTIVE=1
  uf_error "Unexpected failure (exit ${status}) at line ${line}: ${command}"
  uf_error "The desktop may be partially configured."
  if [ -n "${UF_LOG_FILE:-}" ]; then
    uf_error "Details: ${UF_LOG_FILE}"
  fi
  uf_error "Recovery: 'ubuntuify restore' reverts Ubuntuify changes; 'ubuntuify doctor' diagnoses the system."
  exit "$status"
}

# uf_install_traps -- install the ERR trap. Called once from the CLI entrypoint.
uf_install_traps() {
  # shellcheck disable=SC2154  # set by bash
  trap 'uf_on_err "$?" "$LINENO" "$BASH_COMMAND"' ERR
}

# uf_err_clear -- reset the "one error report" guard (used by tests).
uf_err_clear() {
  UF_ERR_TRAP_ACTIVE=0
}

# uf_check_preconditions -- validate the environment before mutating anything.
uf_check_preconditions() {
  if ! uf_have python3; then
    uf_die "python3 is required but was not found on PATH."
  fi
  if ! uf_have gsettings; then
    uf_die "gsettings is required but was not found on PATH (install glib2)."
  fi
  if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ]; then
    uf_die "Refusing to run with an unsafe HOME value: '${HOME:-}'"
  fi
  if [ ! -d "$HOME" ]; then
    uf_die "HOME does not exist: $HOME"
  fi
}
