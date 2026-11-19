# shellcheck shell=bash
# Fedora package detection (read-only).

declare -gA UF_PKG_INSTALLED_CACHE=()
declare -gA UF_PKG_AVAILABLE_CACHE=()

# uf_pkg_installed NAME -- true when the RPM is installed.
uf_pkg_installed() {
  local name="${1:-}"
  [ -n "$name" ] || return 1
  if [ -n "${UF_PKG_INSTALLED_CACHE[$name]:-}" ]; then
    [ "${UF_PKG_INSTALLED_CACHE[$name]}" = "yes" ]
    return
  fi
  if uf_have rpm; then
    if rpm -q --quiet -- "$name" >/dev/null 2>&1; then
      UF_PKG_INSTALLED_CACHE["$name"]="yes"
      return 0
    fi
    UF_PKG_INSTALLED_CACHE["$name"]="no"
    return 1
  fi
  if uf_have dnf; then
    if dnf -q list --installed -- "$name" >/dev/null 2>&1; then
      UF_PKG_INSTALLED_CACHE["$name"]="yes"
      return 0
    fi
  fi
  UF_PKG_INSTALLED_CACHE["$name"]="no"
  return 1
}

# uf_pkg_available NAME -- true when DNF can resolve the package (installed or
# available in an enabled repository).
uf_pkg_available() {
  local name="${1:-}"
  [ -n "$name" ] || return 1
  if uf_pkg_installed "$name"; then
    return 0
  fi
  if [ -n "${UF_PKG_AVAILABLE_CACHE[$name]:-}" ]; then
    [ "${UF_PKG_AVAILABLE_CACHE[$name]}" = "yes" ]
    return
  fi
  if uf_have dnf && dnf -q info -- "$name" >/dev/null 2>&1; then
    UF_PKG_AVAILABLE_CACHE["$name"]="yes"
    return 0
  fi
  UF_PKG_AVAILABLE_CACHE["$name"]="no"
  return 1
}

# uf_pkg_first_installed CANDIDATES -- print the first installed candidate.
# CANDIDATES is a ; separated list.
uf_pkg_first_installed() {
  local candidates="$1" candidate
  while IFS= read -r candidate; do
    if uf_pkg_installed "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(uf_split_list ';' "$candidates")
  return 1
}

# uf_pkg_first_available CANDIDATES -- print the first resolvable candidate.
uf_pkg_first_available() {
  local candidates="$1" candidate
  while IFS= read -r candidate; do
    if uf_pkg_available "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(uf_split_list ';' "$candidates")
  return 1
}

# uf_pkg_installed_list -- all installed RPM names, sorted.
uf_pkg_installed_list() {
  if uf_have rpm; then
    rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort -u
  elif uf_have dnf; then
    dnf -q list --installed 2>/dev/null | awk 'NR > 1 {print $1}' | sort -u
  fi
}

# uf_pkg_count -- number of installed packages (diagnostics only).
uf_pkg_count() {
  uf_pkg_installed_list | wc -l | tr -d ' '
}
