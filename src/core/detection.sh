# shellcheck shell=bash
# Operating system, GNOME and session detection.
#
# Detection never fails the program: unsupported or missing pieces are recorded
# and reported by the doctor. Callers decide what is critical.

UF_DETECTED="${UF_DETECTED:-0}"
UF_DISTRO_ID=""
UF_DISTRO_NAME=""
UF_DISTRO_PRETTY=""
UF_DISTRO_VERSION_ID=""
UF_IS_FEDORA=0
UF_GNOME_AVAILABLE=0
UF_GNOME_VERSION=""
UF_GNOME_MAJOR=""
UF_SESSION_TYPE="unknown"
UF_DESKTOP="unknown"
UF_ARCH=""
UF_HAS_DNF=0
UF_HAS_RPM=0
UF_HAS_GSETTINGS=0
UF_HAS_DCONF=0
UF_HAS_GNOME_EXTENSIONS=0
UF_GSETTINGS_WORKS=0

# uf_os_release_get KEY [FILE] -- read one field from an os-release file
# without executing it.
uf_os_release_get() {
  local key="$1" file="${2:-$UF_OS_RELEASE_FILE}" line value
  [ -r "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "${key}="*)
        value="${line#*=}"
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        printf '%s\n' "$value"
        return 0
        ;;
    esac
  done <"$file"
  return 1
}

# uf_detect_os -- populate distribution fields.
uf_detect_os() {
  UF_DISTRO_ID="$(uf_os_release_get ID || true)"
  UF_DISTRO_NAME="$(uf_os_release_get NAME || true)"
  UF_DISTRO_PRETTY="$(uf_os_release_get PRETTY_NAME || true)"
  UF_DISTRO_VERSION_ID="$(uf_os_release_get VERSION_ID || true)"
  UF_IS_FEDORA=0
  if [ "$(uf_lower "$UF_DISTRO_ID")" = "fedora" ]; then
    UF_IS_FEDORA=1
  fi
  UF_HAS_DNF=0
  uf_have dnf && UF_HAS_DNF=1
  UF_HAS_RPM=0
  uf_have rpm && UF_HAS_RPM=1
}

# uf_detect_gnome -- populate GNOME shell version fields.
uf_detect_gnome() {
  local output="" version="" rpm_version=""
  UF_GNOME_AVAILABLE=0
  UF_GNOME_VERSION=""
  UF_GNOME_MAJOR=""

  if uf_have gnome-shell; then
    UF_GNOME_AVAILABLE=1
    output="$(gnome-shell --version 2>/dev/null || true)"
    if [[ $output =~ ([0-9]+(\.[0-9]+)+) ]]; then
      version="${BASH_REMATCH[1]}"
    fi
  fi

  if [ -z "$version" ] && uf_have rpm; then
    rpm_version="$(rpm -q --qf '%{VERSION}' gnome-shell 2>/dev/null || true)"
    if [[ $rpm_version =~ ^([0-9]+(\.[0-9]+)*) ]]; then
      version="${BASH_REMATCH[1]}"
      UF_GNOME_AVAILABLE=1
    fi
  fi

  if [ -z "$version" ]; then
    # Last resort: the shell's own GSettings schema exists when GNOME is
    # installed, even if the binary is not on PATH (e.g. in a container).
    if uf_have gsettings && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.shell'; then
      UF_GNOME_AVAILABLE=1
    fi
  fi

  UF_GNOME_VERSION="$version"
  if [[ $version =~ ^([0-9]+) ]]; then
    UF_GNOME_MAJOR="${BASH_REMATCH[1]}"
  fi
}

# uf_detect_session -- Wayland/X11 and desktop name.
uf_detect_session() {
  UF_SESSION_TYPE="${XDG_SESSION_TYPE:-}"
  if [ -z "$UF_SESSION_TYPE" ]; then
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
      UF_SESSION_TYPE="wayland"
    elif [ -n "${DISPLAY:-}" ]; then
      UF_SESSION_TYPE="x11"
    else
      UF_SESSION_TYPE="unknown"
    fi
  fi
  UF_SESSION_TYPE="$(uf_lower "$UF_SESSION_TYPE")"

  UF_DESKTOP="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-unknown}}"
}

# uf_detect_tools -- availability of the tools Ubuntuify integrates with.
uf_detect_tools() {
  UF_HAS_GSETTINGS=0
  uf_have gsettings && UF_HAS_GSETTINGS=1
  UF_HAS_DCONF=0
  uf_have dconf && UF_HAS_DCONF=1
  UF_HAS_GNOME_EXTENSIONS=0
  uf_have gnome-extensions && UF_HAS_GNOME_EXTENSIONS=1
  UF_ARCH="$(uname -m 2>/dev/null || printf unknown)"
}

# uf_detect_gsettings_runtime -- verify that GSettings can actually read a
# value (a session bus and dconf are required at runtime).
uf_detect_gsettings_runtime() {
  UF_GSETTINGS_WORKS=0
  if [ "$UF_HAS_GSETTINGS" -eq 0 ]; then
    return 1
  fi
  if gsettings get org.gnome.desktop.interface gtk-theme >/dev/null 2>&1; then
    UF_GSETTINGS_WORKS=1
    return 0
  fi
  return 1
}

# uf_detect_all [--refresh] -- run all detectors once.
uf_detect_all() {
  if [ "${1:-}" != "--refresh" ] && [ "$UF_DETECTED" -eq 1 ]; then
    return 0
  fi
  uf_detect_os
  uf_detect_gnome
  uf_detect_session
  uf_detect_tools
  uf_detect_gsettings_runtime || true
  UF_DETECTED=1
}

# uf_require_fedora -- refuse to run on other distributions unless overridden.
uf_require_fedora() {
  uf_detect_all
  if [ "$UF_IS_FEDORA" -eq 1 ]; then
    return 0
  fi
  if uf_is_true "$UF_ALLOW_UNSUPPORTED"; then
    uf_warn "Not running on Fedora (${UF_DISTRO_PRETTY:-unknown}); continuing because UF_ALLOW_UNSUPPORTED=1."
    return 0
  fi
  uf_die "Ubuntuify Fedora supports Fedora Linux only. Detected: ${UF_DISTRO_PRETTY:-unknown}."
}

# uf_require_gnome -- refuse to apply a GNOME profile without GNOME.
uf_require_gnome() {
  uf_detect_all
  if [ "$UF_GNOME_AVAILABLE" -eq 1 ]; then
    return 0
  fi
  if uf_is_true "$UF_ALLOW_UNSUPPORTED"; then
    uf_warn "GNOME Shell was not detected; continuing because UF_ALLOW_UNSUPPORTED=1."
    return 0
  fi
  uf_die "GNOME Shell was not detected. Ubuntuify Fedora targets Fedora Workstation with GNOME."
}

# uf_detect_summary -- human readable one-line system summary.
uf_detect_summary() {
  uf_detect_all
  printf 'Fedora %s · GNOME %s · %s · %s' \
    "${UF_DISTRO_VERSION_ID:-?}" \
    "${UF_GNOME_VERSION:-not detected}" \
    "${UF_SESSION_TYPE}" \
    "${UF_ARCH:-?}"
}

# uf_detect_versions_changed -- compare detected versions with state.
# Prints "fedora" and/or "gnome" when they changed.
uf_detect_versions_changed() {
  local recorded_fedora recorded_gnome
  recorded_fedora="$(uf_state_get "fedora_version" 2>/dev/null || true)"
  recorded_gnome="$(uf_state_get "gnome_version" 2>/dev/null || true)"
  if [ -n "$recorded_fedora" ] && [ "$recorded_fedora" != "$UF_DISTRO_VERSION_ID" ]; then
    printf 'fedora\n'
  fi
  if [ -n "$recorded_gnome" ] && [ "$recorded_gnome" != "$UF_GNOME_VERSION" ]; then
    printf 'gnome\n'
  fi
}
