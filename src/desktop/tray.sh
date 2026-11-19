# shellcheck shell=bash
# System tray / AppIndicator configuration.

UF_APPINDICATOR_SCHEMA="org.gnome.shell.extensions.appindicator"

# uf_tray_apply -- enable AppIndicator and apply its optional settings.
uf_tray_apply() {
  if ! uf_conf_bool "tray.enabled" true; then
    uf_skip "System tray disabled in configuration."
    return 0
  fi

  local guard_rc=0
  uf_ext_component_guard "tray" || guard_rc=$?
  if [ "$guard_rc" -eq 2 ]; then
    uf_warn "AppIndicator extension is unavailable; tray icons for Telegram, Discord, Steam and VPN clients will not appear."
    return 2
  elif [ "$guard_rc" -ne 0 ]; then
    uf_warn "AppIndicator extension could not be enabled."
    return 1
  fi

  if uf_gs_schema_exists "$UF_APPINDICATOR_SCHEMA"; then
    uf_gs_set "$UF_APPINDICATOR_SCHEMA" icon-size \
      "$(uf_conf_int 'tray.icon_size' 16 8 64)" "Tray icon size"
    uf_gs_set "$UF_APPINDICATOR_SCHEMA" icon-padding \
      "$(uf_conf_int 'tray.icon_padding' 0 0 32)" "Tray icon padding"
  fi

  uf_ok "System tray enabled"
  return 0
}

# uf_tray_status -- summary for status/score.
uf_tray_status() {
  local uuid
  if ! uuid="$(uf_ext_resolve "tray")"; then
    printf 'not installed'
    return 0
  fi
  if uf_ext_is_enabled "$uuid"; then
    printf 'enabled'
  else
    printf 'installed, disabled'
  fi
}
