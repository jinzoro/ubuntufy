# shellcheck shell=bash
# Installation engine: profiles, components, backup, state and rollback.

UF_LOCK_FD=9
UF_LOCK_HELD=0

# uf_lock_acquire -- prevent two Ubuntuify processes from writing at once.
uf_lock_acquire() {
  mkdir -p "$UF_STATE_HOME" 2>/dev/null || true
  if uf_have flock; then
    if ! { exec 9>"$UF_LOCK_FILE"; } 2>/dev/null; then
      return 0
    fi
    if ! flock -n 9; then
      uf_die "Another Ubuntuify process is already running."
    fi
    UF_LOCK_HELD=1
  fi
  return 0
}

# uf_lock_release
uf_lock_release() {
  if [ "${UF_LOCK_HELD:-0}" -eq 1 ]; then
    flock -u 9 2>/dev/null || true
    UF_LOCK_HELD=0
  fi
}

# uf_runtime_init [--probe] -- create directories, start logging, detect.
# --probe skips preconditions and state creation (doctor, status).
uf_runtime_init() {
  local probe=0
  [ "${1:-}" = "--probe" ] && probe=1

  if [ "$probe" -eq 0 ]; then
    uf_check_preconditions
  fi

  local dir
  for dir in "$UF_STATE_HOME" "$UF_STATE_DIR" "$UF_LOG_DIR" "$UF_CACHE_DIR" "$UF_BACKUP_ROOT"; do
    if ! mkdir -p "$dir" 2>/dev/null; then
      if [ "$probe" -eq 0 ]; then
        uf_die "Cannot create ${dir}. Check permissions on ${UF_DATA_HOME}."
      fi
      return 1
    fi
  done

  uf_log_init || true
  uf_lock_acquire
  uf_config_init
  uf_config_validate
  uf_detect_all --refresh

  if [ "$probe" -eq 0 ] && [ "$UF_DRY_RUN" -eq 0 ]; then
    uf_state_init
  fi
  return 0
}

# uf_require_install_target -- Fedora + GNOME are required to apply a profile.
uf_require_install_target() {
  uf_require_fedora
  uf_require_gnome
}

# uf_plan_summary PROFILE -- print a dry-run summary.
uf_plan_summary() {
  local profile="$1"
  shift
  local components=("$@") component
  uf_section "Dry run"
  printf '%s\n' "$(uf_style bold 'Would apply components:')"
  for component in "${components[@]}"; do
    printf '  - %s\n' "$(uf_component_title "$component")"
  done
  printf '\n  profile: %s\n' "$(uf_profile_title "$profile")"
  uf_info "No changes were made (dry run)."
}

# uf_install_prepare_backup PROFILE
uf_install_prepare_backup() {
  local profile="$1" latest current_profile

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would back up the current desktop state before changing it"
    return 0
  fi
  if uf_is_true "$UF_NO_BACKUP"; then
    uf_warn "Automatic backup disabled (--no-backup). You can still run 'ubuntuify backup' afterwards."
    return 0
  fi
  if uf_is_true "$UF_FORCE_BACKUP"; then
    uf_backup_create "install (forced)"
    return 0
  fi

  current_profile="$(uf_state_get profile 2>/dev/null || true)"
  latest="$(uf_backup_latest 2>/dev/null || true)"
  if [ -n "$latest" ] && [ "$current_profile" = "$profile" ]; then
    UF_BACKUP_ID="$latest"
    uf_info "Reusing existing backup ${latest} (force a new one with --backup-now)."
    return 0
  fi
  uf_backup_create "install"
}

# uf_resolve_components PROFILE -- print the components to apply.
uf_resolve_components() {
  local profile="$1" component normalized
  if [ "${#UF_OPT_COMPONENTS[@]}" -gt 0 ]; then
    for component in "${UF_OPT_COMPONENTS[@]}"; do
      normalized="$(uf_component_normalize "$component")"
      if ! uf_component_exists "$normalized"; then
        uf_error "Unknown component '${component}'. Try 'ubuntuify components'."
        return 1
      fi
      printf '%s\n' "$normalized"
    done
    return 0
  fi
  uf_profile_components "$profile"
}

# uf_install -- apply the selected profile/components.
uf_install() {
  local profile components=() component rc status configured=0 skipped=0 failures=0
  local explicit_components=0 prior_profile resolved

  profile="$(uf_conf profile full)"
  if [ -n "${UF_OPT_PROFILE:-}" ]; then
    profile="$UF_OPT_PROFILE"
  fi
  case "$profile" in
    dark) uf_conf_set "color_scheme" "prefer-dark" ;;
    light) profile="full"; uf_conf_set "color_scheme" "default" ;;
  esac
  [ "${#UF_OPT_COMPONENTS[@]}" -gt 0 ] && explicit_components=1
  # A custom profile normally needs custom.components, but an explicit
  # component selection (and an update of a previously installed custom
  # profile) is already a complete specification.
  if [ "$profile" = "custom" ] && [ "$explicit_components" -eq 1 ]; then
    :
  elif ! uf_profile_validate "$profile"; then
    return 1
  fi

  prior_profile="$(uf_state_get profile 2>/dev/null || true)"
  if ! resolved="$(uf_resolve_components "$profile")"; then
    return 1
  fi
  if [ -z "$resolved" ]; then
    uf_error "No components selected; nothing to do."
    return 1
  fi
  mapfile -t components <<<"$resolved"

  uf_require_install_target
  uf_section "Applying ${UF_NAME} (${UF_VERSION})"
  uf_info "System: $(uf_detect_summary)"
  uf_info "Profile: $(uf_profile_title "$profile")"

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_plan_summary "$profile" "${components[@]}"
  fi

  uf_install_prepare_backup "$profile"

  for component in "${components[@]}"; do
    UF_CURRENT_COMPONENT="$component"
    uf_step "$(uf_component_title "$component")"
    rc=0
    uf_component_run "$component" || rc=$?
    case "$rc" in
      0)
        uf_state_component_set "$component" "configured"
        configured=$((configured + 1))
        ;;
      2)
        uf_state_component_set "$component" "skipped"
        skipped=$((skipped + 1))
        ;;
      *)
        uf_state_component_set "$component" "failed"
        failures=$((failures + 1))
        uf_warn "$(uf_component_title "$component") could not be fully applied (see above)."
        ;;
    esac
  done
  UF_CURRENT_COMPONENT="manual"

  if [ "$UF_DRY_RUN" -eq 0 ]; then
    uf_state_update_system
    if [ "$explicit_components" -eq 0 ]; then
      uf_state_set "profile" "$profile"
    elif [ -z "$prior_profile" ]; then
      uf_state_set "profile" "custom"
      uf_state_set "custom_components" "$(IFS=';'; printf '%s' "${components[*]}")"
    fi
    uf_state_set "last_install" "$(uf_datetime)"
  fi

  printf '\n'
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_success "Dry run complete - no changes made."
    return 0
  fi

  if [ "$failures" -gt 0 ]; then
    uf_warn_banner "Applied with ${failures} failed, ${skipped} skipped and ${configured} configured component(s)."
    uf_info "Run 'ubuntuify doctor' for details, or 'ubuntuify restore' to roll back."
    uf_log_tail
    return 1
  fi

  uf_success "Ubuntu profile applied (${configured} configured, ${skipped} skipped)."
  uf_info "Log out and back in (or reboot) so GNOME Shell reloads themes and extensions."
  uf_info "Then check the result with 'ubuntuify status' and 'ubuntuify doctor'."
  uf_log_tail
  return 0
}

# uf_install_component NAME -- apply a single component (used by menus).
uf_install_component() {
  local component
  component="$(uf_component_normalize "$1")"
  if ! uf_component_exists "$component"; then
    uf_error "Unknown component: $1"
    return 1
  fi
  uf_require_install_target
  UF_OPT_COMPONENTS=("$component")
  uf_install
}

# uf_uninstall -- remove the Ubuntuify layer and restore the previous state.
uf_uninstall() {
  local had_state=0
  uf_state_exists && had_state=1

  if [ "$had_state" -eq 0 ]; then
    if [ -n "$(uf_backup_latest 2>/dev/null || true)" ]; then
      uf_info "No Ubuntuify state was found, but backups exist. Use 'ubuntuify restore' to roll back a backup."
    else
      uf_info "Ubuntuify is not installed; nothing to remove."
    fi
    return 0
  fi

  uf_section "Removing Ubuntuify"
  if [ "$UF_DRY_RUN" -eq 0 ] && ! uf_confirm "Remove the Ubuntuify layer and restore your previous GNOME configuration?" n; then
    uf_info "Uninstall cancelled."
    return 1
  fi

  uf_ext_disable_managed

  if [ -d "$UF_PLYMOUTH_THEME_DIR" ] || [ -n "$(uf_state_get "plymouth.previous_theme" 2>/dev/null || true)" ]; then
    uf_plymouth_restore || uf_warn "Plymouth restore reported a problem."
  fi
  if [ -f "$UF_GDM_PROFILE_FILE" ] || uf_is_true "$(uf_state_get "gdm.applied" 2>/dev/null || true)"; then
    uf_gdm_restore || uf_warn "GDM restore reported a problem."
  fi

  uf_gs_restore_originals

  if uf_is_true "$UF_REMOVE_PACKAGES"; then
    uf_pkg_remove_managed || uf_warn "Some packages could not be removed."
  else
    uf_info "Packages installed by Ubuntuify were kept. Remove them with 'ubuntuify uninstall --remove-packages'."
  fi

  if [ "$UF_DRY_RUN" -eq 0 ]; then
    uf_safe_remove_tree "$UF_WALLPAPER_DIR" >/dev/null 2>&1 || true
    uf_safe_remove_tree "$UF_CACHE_DIR" >/dev/null 2>&1 || true
    uf_state_reset
  fi

  uf_success "Ubuntuify removed."
  uf_info "Log out and back in to finish restoring the Fedora desktop."
  uf_info "Backups and logs are kept in ${UF_STATE_HOME}."
  return 0
}

# uf_restore_action [ID] [COMPONENT]
uf_restore_action() {
  local id="${1:-}" component="${2:-}"
  if [ -n "$component" ]; then
    uf_restore_component "$component"
    return $?
  fi
  uf_restore_full "$id"
}

# uf_reset -- reset only Ubuntuify-managed configuration.
uf_reset() {
  uf_section "Resetting Ubuntuify configuration"
  if [ "$UF_DRY_RUN" -eq 0 ] && ! uf_confirm "Reset Ubuntuify-managed settings? Your unrelated GNOME settings and backups are kept." n; then
    uf_info "Reset cancelled."
    return 1
  fi

  uf_ext_disable_managed
  uf_gs_reset_managed
  if [ "$UF_DRY_RUN" -eq 0 ]; then
    uf_state_reset
  fi
  uf_success "Ubuntuify-managed configuration reset."
  uf_info "Log out and back in to see the change."
  return 0
}

# uf_update -- re-apply the installed profile after system updates.
uf_update() {
  local profile failures
  uf_detect_all --refresh
  profile="$(uf_state_get "profile" 2>/dev/null || true)"
  if [ -z "$profile" ]; then
    uf_error "Ubuntuify is not installed. Run 'ubuntuify install' first."
    return 1
  fi

  local changed
  changed="$(uf_detect_versions_changed)"
  if [ -n "$changed" ]; then
    uf_warn "System versions changed since the last install:"
    printf '%s\n' "$changed" | while IFS= read -r entry; do
      [ "$entry" = "fedora" ] && uf_warn "  Fedora: $(uf_state_get fedora_version) -> ${UF_DISTRO_VERSION_ID}"
      [ "$entry" = "gnome" ] && uf_warn "  GNOME: $(uf_state_get gnome_version) -> ${UF_GNOME_VERSION}"
    done
    uf_info "Some extensions may need migration. 'ubuntuify doctor' reports incompatibilities."
  fi

  UF_OPT_PROFILE="$profile"
  UF_OPT_COMPONENTS=()
  if [ "$profile" = "custom" ] && [ -z "$(uf_conf custom.components '')" ]; then
    local saved_components
    saved_components="$(uf_state_get custom_components 2>/dev/null || true)"
    if [ -n "$saved_components" ]; then
      while IFS= read -r entry; do
        [ -n "$entry" ] && UF_OPT_COMPONENTS+=("$entry")
      done < <(uf_split_list ';' "$saved_components")
    fi
  fi
  uf_install
}

# uf_backup_action -- create a manual backup.
uf_backup_action() {
  local id
  uf_section "Backup"
  uf_backup_create "manual"
  uf_success "Backup ${UF_BACKUP_ID} created in ${UF_BACKUP_ROOT}."
  uf_info "Restore it with 'ubuntuify restore --backup ${UF_BACKUP_ID}'."
}

# uf_show_components -- list available components.
uf_show_components() {
  local component installed
  uf_section "Components"
  for component in "${UF_COMPONENT_ORDER[@]}"; do
    installed="$(uf_state_component_get "$component" 2>/dev/null || true)"
    printf '  %-22s %-34s %s\n' "$component" "$(uf_component_title "$component")" "${installed:+[${installed}]}"
  done
}

# uf_switch_appearance light|dark -- switch only the visual layer.
uf_switch_appearance() {
  local mode="$1"
  case "$mode" in
    light)
      uf_config_persist "color_scheme" "default"
      UF_OPT_COMPONENTS=(appearance theme icons cursor wallpaper)
      ;;
    dark)
      uf_config_persist "color_scheme" "prefer-dark"
      UF_OPT_COMPONENTS=(appearance theme icons cursor wallpaper)
      ;;
    *)
      uf_error "Unknown appearance mode: ${mode} (expected light or dark)"
      return 1
      ;;
  esac
  uf_require_install_target
  uf_install
}
