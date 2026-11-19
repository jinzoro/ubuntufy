# shellcheck shell=bash
# Package installation through DNF.
#
# Only packages that Ubuntuify actually needs are installed, and every package
# installed by Ubuntuify is recorded so uninstall can offer targeted cleanup.

# uf_pkg_install NAME LABEL -- install one package and record it.
# Returns 0 on success/already installed, 1 on failure, 2 when unavailable.
uf_pkg_install() {
  local name="$1" label="${2:-$1}" output=""

  if uf_pkg_installed "$name"; then
    uf_ok "${label} already installed (${name})"
    return 0
  fi
  if ! uf_pkg_available "$name"; then
    uf_warn "${label} is not available from the enabled Fedora repositories (${name})."
    return 2
  fi
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would install package: ${name} (${label})"
    return 0
  fi
  if ! uf_have dnf; then
    uf_warn "DNF is not available; cannot install ${name}."
    return 1
  fi

  uf_step "Installing ${label} (${name})"
  if output="$(uf_run_root dnf install -y --setopt=install_weak_deps=False -- "$name" 2>&1)"; then
    uf_log_write "DNF" "installed ${name}"
    if uf_pkg_installed "$name"; then
      uf_state_add "installed_packages" "$name"
      uf_ok "Installed ${label} (${name})"
      return 0
    fi
    uf_warn "DNF reported success but ${name} is not installed."
    return 1
  fi
  uf_log_write "DNF" "failed to install ${name}: ${output}"
  uf_warn "Could not install ${label} (${name}). See the log for details."
  uf_debug "$(printf '%s\n' "$output" | tail -n 3)"
  return 1
}

# uf_pkg_install_first CANDIDATES LABEL -- install the first candidate that is
# already installed or available. On success the chosen package is stored in
# UF_PKG_CHOSEN (not printed, so callers can capture safely).
UF_PKG_CHOSEN=""
uf_pkg_install_first() {
  local candidates="$1" label="${2:-$1}" package=""
  UF_PKG_CHOSEN=""

  if package="$(uf_pkg_first_installed "$candidates")"; then
    uf_ok "${label} already installed (${package})"
    UF_PKG_CHOSEN="$package"
    return 0
  fi

  package="$(uf_pkg_first_available "$candidates" || true)"
  if [ -z "$package" ]; then
    uf_warn "${label} is not packaged in the enabled Fedora repositories."
    return 2
  fi

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would install package: ${package} (${label})"
    UF_PKG_CHOSEN="$package"
    return 0
  fi

  if uf_pkg_install "$package" "$label"; then
    UF_PKG_CHOSEN="$package"
    return 0
  fi
  return 1
}

# uf_pkg_install_many NAME... -- install several packages, reporting failures
# without aborting the rest of the profile.
uf_pkg_install_many() {
  local name failures=0
  for name in "$@"; do
    uf_pkg_install "$name" "$name" || failures=$((failures + 1))
  done
  [ "$failures" -eq 0 ]
}

# uf_pkg_refresh_metadata -- refresh DNF metadata only when the user allows it.
uf_pkg_refresh_metadata() {
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would refresh DNF metadata"
    return 0
  fi
  if ! uf_have dnf; then
    return 1
  fi
  uf_step "Refreshing DNF metadata"
  if uf_run_root dnf -q makecache >/dev/null 2>&1; then
    uf_debug "DNF metadata refreshed"
    return 0
  fi
  uf_warn "Could not refresh DNF metadata; using cached data."
  return 1
}
