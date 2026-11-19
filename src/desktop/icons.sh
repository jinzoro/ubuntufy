# shellcheck shell=bash
# Desktop icons (Home, Trash, mounted volumes) via Desktop Icons NG.

uf_ding_schema() {
  local schema
  for schema in \
    "org.gnome.shell.extensions.ding" \
    "org.gnome.shell.extensions.desktop-icons-ng"; do
    if uf_gs_schema_exists "$schema"; then
      printf '%s\n' "$schema"
      return 0
    fi
  done
  return 1
}

# uf_desktop_icons_apply
uf_desktop_icons_apply() {
  local schema

  if ! uf_conf_bool "desktop_icons.enabled" true; then
    uf_skip "Desktop icons disabled in configuration."
    return 0
  fi

  local guard_rc=0
  uf_ext_component_guard "desktop-icons" || guard_rc=$?
  if [ "$guard_rc" -eq 2 ]; then
    uf_warn "Desktop Icons NG is unavailable; desktop icons will stay disabled."
    return 2
  elif [ "$guard_rc" -ne 0 ]; then
    uf_warn "Desktop Icons NG could not be enabled; skipping desktop icon configuration."
    return 1
  fi

  if ! schema="$(uf_ding_schema)"; then
    uf_warn "Desktop Icons NG settings schema was not found; log out and back in, then run 'ubuntuify install --component desktop-icons'."
    return 2
  fi

  uf_gs_set "$schema" show-home \
    "$(uf_conf_bool desktop_icons.home true && printf true || printf false)" "Desktop: Home icon"
  uf_gs_set "$schema" show-trash \
    "$(uf_conf_bool desktop_icons.trash true && printf true || printf false)" "Desktop: Trash icon"
  uf_gs_set "$schema" show-volumes \
    "$(uf_conf_bool desktop_icons.volumes true && printf true || printf false)" "Desktop: mounted volumes"
  uf_gs_set "$schema" show-network-volumes \
    "$(uf_conf_bool desktop_icons.network_volumes true && printf true || printf false)" "Desktop: network volumes"
  uf_gs_set "$schema" icon-size \
    "'$(uf_conf desktop_icons.icon_size standard)'" "Desktop: icon size"
  uf_gs_set "$schema" start-corner \
    "'$(uf_conf desktop_icons.start_corner top-left)'" "Desktop: icon layout corner"
  uf_gs_set "$schema" show-drop-placeholder \
    "$(uf_conf_bool desktop_icons.show_drop_placeholder true && printf true || printf false)" "Desktop: drop placeholder"

  uf_ok "Desktop icons configured"
  return 0
}

# uf_desktop_icons_status -- summary for status/score.
uf_desktop_icons_status() {
  local schema
  if ! schema="$(uf_ding_schema)"; then
    printf 'not installed'
    return 0
  fi
  printf 'home=%s trash=%s volumes=%s' \
    "$(uf_gs_value "$schema" show-home '?')" \
    "$(uf_gs_value "$schema" show-trash '?')" \
    "$(uf_gs_value "$schema" show-volumes '?')"
}
