# shellcheck shell=bash
# Restore and rollback.

# uf_restore_resolve_id [ID] -- validate an id or return the newest backup.
uf_restore_resolve_id() {
  local id="${1:-}"
  if [ -z "$id" ]; then
    id="$(uf_backup_latest)"
  fi
  if ! uf_backup_exists "$id"; then
    uf_error "Backup not found: ${id:-<none>}"
    return 1
  fi
  printf '%s\n' "$id"
}

# uf_restore_files DIR -- restore archived configuration files.
uf_restore_files() {
  local dir="$1" archive="${1}/user-config.tar"
  [ -f "$archive" ] || return 0
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would restore user configuration files from ${archive}"
    return 0
  fi
  if tar -tf "$archive" >/dev/null 2>&1; then
    if tar -xf "$archive" -C "$HOME" 2>/dev/null; then
      uf_ok "Restored user configuration files"
    else
      uf_warn "Could not restore all user configuration files from ${archive}"
    fi
  else
    uf_warn "Backup archive is unreadable: ${archive}"
  fi
}

# uf_restore_dconf DIR -- load a dconf dump. Returns 1 when unusable.
uf_restore_dconf() {
  local dir="$1" dump="${1}/dconf.dump"
  [ -s "$dump" ] || return 1
  if ! uf_have dconf; then
    uf_warn "dconf is not available; falling back to recorded settings."
    return 1
  fi
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would load the dconf backup from ${dump}"
    return 0
  fi
  if dconf load / <"$dump" 2>/dev/null; then
    uf_ok "Restored dconf database"
    return 0
  fi
  uf_warn "Could not load the dconf backup; falling back to recorded settings."
  return 1
}

# uf_restore_full [ID] -- restore a complete backup.
uf_restore_full() {
  local id dir
  id="$(uf_restore_resolve_id "${1:-}")" || return 1
  dir="${UF_BACKUP_ROOT}/${id}"

  uf_section "Restore backup ${id}"
  uf_backup_verify "$id" || return 1

  if [ "$UF_DRY_RUN" -eq 0 ] && ! uf_confirm "Restore the desktop state saved in backup ${id}? Current desktop settings will be replaced." n; then
    uf_info "Restore cancelled."
    return 1
  fi

  if ! uf_restore_dconf "$dir"; then
    uf_info "Restoring only settings recorded by Ubuntuify."
    uf_gs_restore_originals
  fi

  uf_restore_files "$dir"

  if [ -f "${dir}/state.json" ] && [ "$UF_DRY_RUN" -eq 0 ]; then
    cp -- "${dir}/state.json" "$UF_STATE_FILE" 2>/dev/null || true
  fi

  if [ "$UF_DRY_RUN" -eq 0 ]; then
    rm -f -- "$UF_ORIGINAL_SETTINGS" "$UF_APPLIED_SETTINGS" 2>/dev/null || true
    touch -- "$UF_ORIGINAL_SETTINGS" "$UF_APPLIED_SETTINGS" 2>/dev/null || true
    uf_state_component_set "restored" "$(uf_datetime)"
  fi

  uf_success "Restored backup ${id}."
  uf_info "Log out and back in (or reboot) so GNOME Shell reloads themes and extensions."
  return 0
}

# uf_restore_component NAME -- restore one component only.
uf_restore_component() {
  local component
  component="$(uf_component_normalize "${1:-}")"
  if [ -z "$component" ]; then
    uf_error "restore --component requires a component name."
    return 1
  fi
  if ! uf_component_exists "$component"; then
    uf_error "Unknown component: ${1}. Try 'ubuntuify components'."
    return 1
  fi

  case "$component" in
    plymouth)
      uf_plymouth_restore
      return $?
      ;;
    gdm)
      uf_gdm_restore
      return $?
      ;;
    *)
      # Extension enablement lives in GSettings; the originals log covers it.
      uf_gs_restore_originals "$component"
      ;;
  esac
  uf_success "Restored component: ${component}"
  uf_info "Log out and back in if the change is not visible immediately."
  return 0
}

# uf_restore_note -- explain what restore can and cannot undo.
uf_restore_note() {
  cat <<'EOF'
Restore notes:
  * dconf/GSettings, favorites, extensions and theme settings are restored.
  * Files installed under /usr/share by optional boot components are removed
    by 'ubuntuify restore --component plymouth|gdm'.
  * Packages are never removed implicitly; use 'ubuntuify uninstall --remove-packages'.
  * GNOME Shell changes require a logout/login or a reboot. Alt+F2 "r" is not
    supported on Wayland.
EOF
}
