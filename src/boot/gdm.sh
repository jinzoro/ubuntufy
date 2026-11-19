# shellcheck shell=bash
# Optional GDM login-screen branding.
#
# Modern Fedora GDM does not support a custom login theme without patching
# GDM itself, which Ubuntuify will not do. What can be done safely is setting
# the greeter background through a GDM dconf profile drop-in. This is opt-in,
# requires root and is reversible.

UF_GDM_PROFILE_FILE="/etc/dconf/db/gdm.d/99-ubuntuify"
UF_GDM_BACKGROUND_DIR="/usr/share/backgrounds/ubuntuify"

# uf_gdm_available
uf_gdm_available() {
  [ -d /etc/gdm ] || uf_have gdm
}

# uf_gdm_apply
uf_gdm_apply() {
  local dark=0 path backup_dir
  if ! uf_gdm_available; then
    uf_warn "GDM was not detected; login screen branding is unavailable."
    return 2
  fi

  uf_warn "Ubuntu's Yaru GDM theme cannot be reproduced on Fedora without patching GDM."
  uf_info "Ubuntuify can only set the greeter background through a supported dconf profile."
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_theme_is_dark && dark=1
    uf_dry "Would set the GDM greeter background and run dconf update"
    return 0
  fi
  if ! uf_confirm_root_action "set the GDM greeter background"; then
    return 2
  fi

  uf_theme_is_dark && dark=1

  # Back up any pre-existing drop-in from an older run, without replacing an
  # existing backup copy.
  if [ -f "$UF_GDM_PROFILE_FILE" ]; then
    backup_dir="${UF_BACKUP_ROOT}/${UF_BACKUP_ID:-manual}/gdm"
    mkdir -p "$backup_dir"
    if [ ! -e "${backup_dir}/99-ubuntuify" ]; then
      cp -- "$UF_GDM_PROFILE_FILE" "${backup_dir}/99-ubuntuify" 2>/dev/null || true
    fi
  fi

  if ! path="$(uf_wallpaper_generate "$dark")"; then
    uf_warn "Could not generate a GDM background."
    return 1
  fi

  if ! uf_run_root mkdir -p "$UF_GDM_BACKGROUND_DIR"; then
    uf_warn "Could not create ${UF_GDM_BACKGROUND_DIR}."
    return 1
  fi
  if ! uf_run_root cp -f -- "$path" "${UF_GDM_BACKGROUND_DIR}/gdm.png"; then
    uf_warn "Could not copy the GDM background."
    return 1
  fi

  local staging="${UF_CACHE_DIR}/gdm-profile"
  mkdir -p "$staging"
  cat >"${staging}/99-ubuntuify" <<'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/ubuntuify/gdm.png'
picture-uri-dark='file:///usr/share/backgrounds/ubuntuify/gdm.png'
picture-options='zoom'
primary-color='#2c001e'
EOF
  if ! uf_run_root install -m 0644 -- "${staging}/99-ubuntuify" "$UF_GDM_PROFILE_FILE"; then
    uf_warn "Could not install the GDM dconf profile."
    return 1
  fi
  if ! uf_run_root dconf update; then
    uf_warn "Could not update the dconf database; the greeter background may not change."
    return 1
  fi
  uf_state_set "gdm.applied" "true"
  uf_ok "GDM greeter background configured"
  uf_info "The greeter is not restarted automatically; it changes on the next logout."
  return 0
}

# uf_gdm_restore
uf_gdm_restore() {
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would remove the Ubuntuify GDM profile and update dconf"
    return 0
  fi
  if [ ! -d /etc/gdm ]; then
    uf_info "GDM is not installed; nothing to restore."
    return 0
  fi
  if [ -f "$UF_GDM_PROFILE_FILE" ]; then
    if ! uf_run_root rm -f -- "$UF_GDM_PROFILE_FILE"; then
      uf_warn "Could not remove ${UF_GDM_PROFILE_FILE}."
      return 1
    fi
  fi
  uf_run_root dconf update >/dev/null 2>&1 || true
  uf_run_root rm -rf -- "$UF_GDM_BACKGROUND_DIR" >/dev/null 2>&1 || true
  uf_state_delete "gdm"
  uf_ok "GDM branding restored"
  return 0
}

# uf_gdm_status
uf_gdm_status() {
  if ! uf_gdm_available; then
    printf 'not installed'
  elif [ -f "$UF_GDM_PROFILE_FILE" ]; then
    printf 'background configured'
  else
    printf 'not configured'
  fi
}
