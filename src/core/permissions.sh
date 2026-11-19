# shellcheck shell=bash
# Root privilege handling.
#
# Ubuntuify always runs as the normal user. Only individual package or
# boot-branding operations are escalated through sudo.

# uf_is_root -- true when the current user is root.
uf_is_root() {
  [ "$(id -u)" -eq 0 ]
}

# uf_can_sudo -- true when a non-interactive or interactive sudo is usable.
uf_can_sudo() {
  uf_have sudo || return 1
  sudo -n true >/dev/null 2>&1 && return 0
  [ -t 0 ] && return 0
  return 1
}

# uf_require_sudo -- fail early with a clear message when sudo is unusable.
uf_require_sudo() {
  if uf_is_root; then
    return 0
  fi
  if ! uf_have sudo; then
    uf_die "This operation needs root privileges but sudo is not installed."
  fi
  if ! sudo -n true >/dev/null 2>&1 && [ ! -t 0 ]; then
    uf_die "This operation needs root privileges. Run it from an interactive terminal with sudo configured."
  fi
  return 0
}

# uf_run_root COMMAND... -- run a command as root (sudo only when needed).
#
# In dry-run mode this must never be called; callers check UF_DRY_RUN first.
uf_run_root() {
  if uf_is_root; then
    "$@"
    return
  fi
  uf_require_sudo
  if [ -t 0 ]; then
    sudo -- "$@"
  else
    sudo -n -- "$@"
  fi
}

# uf_confirm_root_action DESCRIPTION -- ask before a risky system change.
uf_confirm_root_action() {
  local description="$1"
  uf_warn "Root action: ${description}"
  if uf_is_true "$UF_ASSUME_YES"; then
    uf_debug "Automation mode: accepting root action."
    return 0
  fi
  uf_confirm "Proceed with this system change?" n
}
