# shellcheck shell=bash
# ubuntuify doctor - diagnose the system and the Ubuntuify layer.

UF_DOCTOR_FAILS="${UF_DOCTOR_FAILS:-0}"
UF_DOCTOR_WARNS="${UF_DOCTOR_WARNS:-0}"

# uf_doctor_line STATUS TEXT
uf_doctor_line() {
  local status="$1" text="$2"
  case "$status" in
    ok) printf '  %s %s\n' "$(uf_style green '✓')" "$text" ;;
    fail)
      printf '  %s %s\n' "$(uf_style red '✗')" "$text"
      UF_DOCTOR_FAILS=$((UF_DOCTOR_FAILS + 1))
      ;;
    warn)
      printf '  %s %s\n' "$(uf_style yellow '⚠')" "$text"
      UF_DOCTOR_WARNS=$((UF_DOCTOR_WARNS + 1))
      ;;
    *) printf '  %s %s\n' "$(uf_style dim '○')" "$text" ;;
  esac
}

# uf_doctor_system -- OS, GNOME, tools.
uf_doctor_system() {
  uf_section "System"
  if [ "$UF_IS_FEDORA" -eq 1 ]; then
    uf_doctor_line ok "Fedora detected (${UF_DISTRO_PRETTY:-Fedora ${UF_DISTRO_VERSION_ID}})"
  else
    uf_doctor_line fail "Fedora not detected (${UF_DISTRO_PRETTY:-unknown})"
  fi

  if [ "$UF_GNOME_AVAILABLE" -eq 1 ]; then
    uf_doctor_line ok "GNOME detected (${UF_GNOME_VERSION:-version unknown})"
  else
    uf_doctor_line fail "GNOME Shell not detected"
  fi

  if [ -n "$UF_GNOME_MAJOR" ] && [ "$UF_GNOME_MAJOR" -lt 45 ] 2>/dev/null; then
    uf_doctor_line warn "GNOME ${UF_GNOME_VERSION} is older than the supported baseline (GNOME 45+)"
  fi

  case "$UF_SESSION_TYPE" in
    wayland) uf_doctor_line ok "Wayland session" ;;
    x11) uf_doctor_line warn "X11 session (Wayland is the primary target; settings still apply)" ;;
    *) uf_doctor_line warn "Session type unknown (not running inside a desktop session?)" ;;
  esac

  uf_doctor_line ok "Architecture: ${UF_ARCH:-unknown}"

  if [ "$UF_IS_FEDORA" -eq 1 ]; then
    local version="${UF_DISTRO_VERSION_ID%%.*}"
    if uf_validate_int "$version" 44 999; then
      uf_doctor_line ok "Fedora ${UF_DISTRO_VERSION_ID} (tested baseline: Fedora 44+)"
    else
      uf_doctor_line warn "Fedora ${UF_DISTRO_VERSION_ID} is older than the tested baseline (Fedora 44+)"
    fi
  fi
}

# uf_doctor_tools -- command availability.
uf_doctor_tools() {
  uf_section "Tools"
  if uf_have gsettings; then
    uf_doctor_line ok "GSettings available"
  else
    uf_doctor_line fail "gsettings is missing (install glib2)"
  fi
  if uf_have dconf; then
    uf_doctor_line ok "dconf available"
  else
    uf_doctor_line warn "dconf is missing; full backup/restore is limited"
  fi
  if uf_have dnf; then
    uf_doctor_line ok "DNF available"
  else
    uf_doctor_line fail "DNF is missing"
  fi
  if uf_have rpm; then
    uf_doctor_line ok "RPM available"
  else
    uf_doctor_line warn "rpm is missing"
  fi
  if uf_have gnome-extensions; then
    uf_doctor_line ok "gnome-extensions available"
  else
    uf_doctor_line warn "gnome-extensions is missing; extensions can only be configured for the next login"
  fi
  if [ "$UF_GSETTINGS_WORKS" -eq 1 ]; then
    uf_doctor_line ok "GSettings is readable in this session"
  else
    uf_doctor_line fail "GSettings cannot be read (is a session bus available?)"
  fi
}

# uf_doctor_theme -- theme, icons, cursor, fonts.
uf_doctor_theme() {
  uf_section "Theme"
  if uf_theme_dir_exists "Yaru"; then
    uf_doctor_line ok "Yaru GTK theme installed"
  else
    uf_doctor_line warn "Yaru GTK theme not installed"
  fi
  if uf_theme_shell_exists "Yaru"; then
    uf_doctor_line ok "Yaru GNOME Shell theme installed"
  else
    uf_doctor_line warn "Yaru GNOME Shell theme not installed on this Fedora release"
  fi
  if uf_icon_theme_exists "Yaru"; then
    uf_doctor_line ok "Yaru icon theme installed"
  else
    uf_doctor_line warn "Yaru icon theme not installed"
  fi
  if uf_cursor_theme_exists "Yaru"; then
    uf_doctor_line ok "Yaru cursor theme installed"
  else
    uf_doctor_line warn "Yaru cursor theme not packaged by Fedora (known gap)"
  fi
  if uf_font_family_installed "Ubuntu"; then
    uf_doctor_line ok "Ubuntu fonts installed"
  else
    uf_doctor_line warn "Ubuntu fonts not installed (known Fedora packaging gap; current fonts kept)"
  fi

  local gtk_theme icons cursor
  gtk_theme="$(uf_gs_value org.gnome.desktop.interface gtk-theme '?')"
  icons="$(uf_gs_value org.gnome.desktop.interface icon-theme '?')"
  cursor="$(uf_gs_value org.gnome.desktop.interface cursor-theme '?')"
  uf_doctor_line "$([ "$gtk_theme" != "?" ] && printf ok || printf warn)" "Active GTK theme: ${gtk_theme}"
  uf_doctor_line "$([ "$icons" != "?" ] && printf ok || printf warn)" "Active icon theme: ${icons}"
  uf_doctor_line "$([ "$cursor" != "?" ] && printf ok || printf warn)" "Active cursor theme: ${cursor}"
}

# uf_doctor_extensions -- required extension states.
uf_doctor_extensions() {
  uf_section "Extensions"
  uf_ext_load_registry || return 0
  local name uuid
  for name in "${UF_EXT_NAMES[@]}"; do
    if uuid="$(uf_ext_resolve "$name")"; then
      if uf_ext_is_enabled "$uuid"; then
        uf_doctor_line ok "${UF_EXT_LABEL[$name]} installed and enabled"
      else
        uf_doctor_line warn "${UF_EXT_LABEL[$name]} installed but disabled (${uuid})"
      fi
      local compatibility
      compatibility="$(uf_ext_compatible "$uuid")"
      if [ "$compatibility" = "no" ]; then
        uf_doctor_line fail "${UF_EXT_LABEL[$name]} does not support GNOME ${UF_GNOME_MAJOR}"
      fi
    else
      case "$name" in
        tray | desktop-icons | dock)
          uf_doctor_line warn "${UF_EXT_LABEL[$name]} not installed"
          ;;
        *)
          uf_doctor_line skip "${UF_EXT_LABEL[$name]} not installed (optional)"
          ;;
      esac
    fi
  done
}

# uf_doctor_desktop -- live desktop values.
uf_doctor_desktop() {
  uf_section "Desktop"
  local layout
  layout="$(uf_gs_value org.gnome.desktop.wm.preferences button-layout '?')"
  case "$layout" in
    *minimize*maximize*close*) uf_doctor_line ok "Window buttons: ${layout}" ;;
    *) uf_doctor_line warn "Window buttons are not Ubuntu-like: ${layout}" ;;
  esac

  if uf_gs_schema_exists "org.gnome.shell.extensions.dash-to-dock"; then
    local dock_position dock_enabled
    dock_position="$(uf_gs_value org.gnome.shell.extensions.dash-to-dock dock-position '?')"
    if [ "$dock_position" = "left" ]; then
      uf_doctor_line ok "Dock positioned on the left"
    else
      uf_doctor_line warn "Dock position is ${dock_position}, expected left"
    fi
    if uf_dock_extension_uuid_ok; then
      uf_doctor_line ok "Dock extension active"
    else
      uf_doctor_line warn "Dock extension is not enabled"
    fi
  else
    uf_doctor_line warn "Dock settings schema not available"
  fi

  if uf_gs_schema_exists "org.gnome.shell.extensions.ding"; then
    uf_doctor_line ok "Desktop Icons NG settings available"
  else
    uf_doctor_line warn "Desktop Icons NG is not installed"
  fi

  if uf_state_has "installed_packages" "yaru-theme"; then
    uf_doctor_line ok "Yaru package recorded as installed by Ubuntuify"
  fi
}

# uf_dock_extension_uuid_ok -- helper for doctor.
uf_dock_extension_uuid_ok() {
  local uuid
  uuid="$(uf_ext_resolve "dock" 2>/dev/null || true)"
  [ -n "$uuid" ] && uf_ext_is_enabled "$uuid"
}

# uf_doctor_backup -- backups and state.
uf_doctor_backup() {
  uf_section "Backup and state"
  local latest
  latest="$(uf_backup_latest)"
  if [ -n "$latest" ]; then
    uf_doctor_line ok "Backup available: ${latest}"
  else
    uf_doctor_line warn "No backup found (run 'ubuntuify backup')"
  fi

  if [ -w "$HOME" ]; then
    uf_doctor_line ok "Home directory is writable"
  else
    uf_doctor_line fail "Home directory is not writable"
  fi

  if uf_state_exists; then
    uf_doctor_line ok "State file present"
  else
    uf_doctor_line skip "Ubuntuify is not installed"
  fi

  local available_kb
  available_kb="$(df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')"
  if [[ $available_kb =~ ^[0-9]+$ ]] && [ "$available_kb" -lt 524288 ]; then
    uf_doctor_line warn "Low disk space: $((available_kb / 1024)) MiB free"
  else
    uf_doctor_line ok "Disk space sufficient ($((available_kb / 1024)) MiB free)"
  fi
}

# uf_doctor_boot -- optional components.
uf_doctor_boot() {
  uf_section "Boot / login"
  uf_doctor_line skip "Plymouth: $(uf_plymouth_status)"
  uf_doctor_line skip "GDM: $(uf_gdm_status)"
  if uf_is_root; then
    uf_doctor_line warn "Running as root; Ubuntuify should normally run as your user"
  else
    uf_doctor_line ok "Running as a normal user"
  fi
}

# uf_doctor -- full diagnostic run. Returns 1 when critical problems exist.
uf_doctor() {
  UF_DOCTOR_FAILS=0
  UF_DOCTOR_WARNS=0
  uf_detect_all --refresh

  uf_section "Ubuntuify Doctor"
  uf_info "System: $(uf_detect_summary)"
  uf_doctor_system
  uf_doctor_tools
  uf_doctor_theme
  uf_doctor_extensions
  uf_doctor_desktop
  uf_doctor_backup
  uf_doctor_boot

  printf '\n'
  if [ "$UF_DOCTOR_FAILS" -eq 0 ]; then
    uf_success "No critical problems found."
    if [ "$UF_DOCTOR_WARNS" -gt 0 ]; then
      uf_warn_banner "${UF_DOCTOR_WARNS} warning(s) - see above."
    fi
    uf_log_tail
    return 0
  fi
  uf_error "${UF_DOCTOR_FAILS} critical problem(s) and ${UF_DOCTOR_WARNS} warning(s) found."
  uf_info "Recovery: 'ubuntuify restore' reverts Ubuntuify changes; see docs/troubleshooting.md."
  uf_log_tail
  return 1
}
