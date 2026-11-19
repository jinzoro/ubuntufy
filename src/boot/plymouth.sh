# shellcheck shell=bash
# Optional Ubuntu-style Plymouth boot branding.
#
# This is never applied by a profile. It requires the explicit
# --component plymouth flag, a confirmation and root privileges, and it is
# fully reversible with 'ubuntuify restore --component plymouth'.

UF_PLYMOUTH_THEME="ubuntuify"
UF_PLYMOUTH_THEME_DIR="/usr/share/plymouth/themes/${UF_PLYMOUTH_THEME}"

# uf_plymouth_available
uf_plymouth_available() {
  uf_have plymouth-set-default-theme && [ -d /usr/share/plymouth/themes ]
}

# uf_plymouth_current_theme -- print the active Plymouth theme name.
uf_plymouth_current_theme() {
  local theme=""
  theme="$(plymouth-set-default-theme 2>/dev/null || true)"
  theme="$(printf '%s' "$theme" | head -n 1)"
  if [ -z "$theme" ] && [ -r /etc/plymouth/plymouthd.conf ]; then
    theme="$(sed -n 's/^Theme=//p' /etc/plymouth/plymouthd.conf | head -n 1)"
  fi
  printf '%s\n' "$theme"
}

# uf_plymouth_write_theme DIR -- generate the theme files.
uf_plymouth_write_theme() {
  local dir="$1"
  mkdir -p "$dir"
  python3 "${UF_SRC}/core/artwork.py" plymouth-logo "${dir}/logo.png" 256 || return 1

  cat >"${dir}/${UF_PLYMOUTH_THEME}.plymouth" <<EOF
[Plymouth Theme]
Name=Ubuntuify
Description=Ubuntu-style boot splash for Fedora
ModuleName=script

[script]
ImageDir=${UF_PLYMOUTH_THEME_DIR}
ScriptFile=${UF_PLYMOUTH_THEME_DIR}/${UF_PLYMOUTH_THEME}.script
EOF

  cat >"${dir}/${UF_PLYMOUTH_THEME}.script" <<'EOF'
# Ubuntuify Fedora - simple Ubuntu-style boot splash.
# Original artwork and colours; no Ubuntu assets are redistributed.
Window.SetBackgroundTopColor(0.17, 0.0, 0.12);
Window.SetBackgroundBottomColor(0.37, 0.15, 0.31);

logo = Image("logo.png");
logo_sprite = Sprite(logo);
logo_sprite.SetX((Window.GetWidth() - logo.GetWidth()) / 2);
logo_sprite.SetY((Window.GetHeight() - logo.GetHeight()) / 2);
EOF
}

# uf_plymouth_apply -- install and activate the generated theme.
uf_plymouth_apply() {
  local previous staging

  if ! uf_plymouth_available; then
    uf_warn "Plymouth is not installed; boot branding is unavailable."
    return 2
  fi

  uf_warn "This changes the boot splash and rebuilds the initramfs."
  uf_info "It is reversible with 'ubuntuify restore --component plymouth'."
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would install Plymouth theme '${UF_PLYMOUTH_THEME}' and rebuild the initramfs"
    return 0
  fi
  if ! uf_confirm_root_action "install the Ubuntuify Plymouth boot theme"; then
    uf_info "Plymouth theme not installed."
    return 2
  fi

  previous="$(uf_plymouth_current_theme)"
  if [ -n "$previous" ] && [ "$previous" != "$UF_PLYMOUTH_THEME" ]; then
    if [ -z "$(uf_state_get "plymouth.previous_theme" 2>/dev/null || true)" ]; then
      uf_state_set "plymouth.previous_theme" "$previous"
      uf_info "Previous Plymouth theme recorded: ${previous}"
    else
      uf_info "Keeping the original Plymouth theme recorded in state."
    fi
  elif [ "$previous" = "$UF_PLYMOUTH_THEME" ]; then
    uf_info "Ubuntuify Plymouth branding is already active."
  fi
  # Keep a copy of the existing configuration next to the desktop backup.
  # plymouth-set-default-theme can regenerate it, but an explicit copy makes
  # manual recovery possible if the theme tool is unavailable. Never replace
  # an existing backup copy.
  local backup_dir="${UF_BACKUP_ROOT}/${UF_BACKUP_ID:-manual}/plymouth"
  if [ -r /etc/plymouth/plymouthd.conf ] && [ ! -e "${backup_dir}/plymouthd.conf" ]; then
    mkdir -p "$backup_dir"
    cp -- /etc/plymouth/plymouthd.conf "${backup_dir}/plymouthd.conf" 2>/dev/null ||
      uf_warn "Could not copy the existing Plymouth configuration into the backup."
  fi

  staging="${UF_CACHE_DIR}/plymouth"
  uf_safe_remove_tree "$staging" >/dev/null 2>&1 || true
  mkdir -p "$staging"
  if ! uf_plymouth_write_theme "$staging"; then
    uf_warn "Could not generate the Plymouth theme files."
    return 1
  fi

  if ! uf_run_root mkdir -p "$UF_PLYMOUTH_THEME_DIR"; then
    uf_warn "Could not create ${UF_PLYMOUTH_THEME_DIR}."
    return 1
  fi
  if ! uf_run_root cp -f -- "${staging}/${UF_PLYMOUTH_THEME}.plymouth" \
    "${staging}/${UF_PLYMOUTH_THEME}.script" "${staging}/logo.png" "$UF_PLYMOUTH_THEME_DIR/"; then
    uf_warn "Could not install the Plymouth theme files."
    return 1
  fi

  uf_step "Rebuilding initramfs (this can take a minute)"
  if uf_run_root plymouth-set-default-theme -R "$UF_PLYMOUTH_THEME"; then
    uf_ok "Plymouth theme installed: ${UF_PLYMOUTH_THEME}"
    uf_info "The new boot splash appears after the next reboot."
    return 0
  fi

  uf_warn "Could not activate the Plymouth theme; files were installed but the default was not changed."
  return 1
}

# uf_plymouth_restore -- restore the previous theme and remove ours.
uf_plymouth_restore() {
  local previous
  previous="$(uf_state_get "plymouth.previous_theme" 2>/dev/null || true)"

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would restore Plymouth theme '${previous:-system default}' and remove ${UF_PLYMOUTH_THEME_DIR}"
    return 0
  fi

  if [ -n "$previous" ] && uf_plymouth_available; then
    uf_step "Restoring Plymouth theme: ${previous}"
    if ! uf_run_root plymouth-set-default-theme -R "$previous"; then
      uf_warn "Could not restore Plymouth theme ${previous}."
      return 1
    fi
  elif uf_plymouth_available; then
    # The state file can be missing after a manual cleanup. Fedora Workstation
    # uses bgrt, so restore that instead of leaving a dangling theme name.
    uf_warn "No previous Plymouth theme was recorded; restoring the Fedora default (bgrt)."
    uf_run_root plymouth-set-default-theme -R bgrt || {
      uf_warn "Could not restore the Fedora default Plymouth theme."
      return 1
    }
  fi

  if [ -d "$UF_PLYMOUTH_THEME_DIR" ]; then
    uf_run_root rm -rf -- "$UF_PLYMOUTH_THEME_DIR"
  fi
  uf_state_delete "plymouth"
  uf_ok "Plymouth branding restored"
  return 0
}

# uf_plymouth_status -- summary for status/diagnostics.
uf_plymouth_status() {
  if ! uf_plymouth_available; then
    printf 'not installed'
    return 0
  fi
  if [ -d "$UF_PLYMOUTH_THEME_DIR" ]; then
    printf 'Ubuntuify theme installed (%s)' "$(uf_plymouth_current_theme)"
  else
    printf 'active: %s' "$(uf_plymouth_current_theme)"
  fi
}
