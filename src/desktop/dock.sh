# shellcheck shell=bash
# Ubuntu-style dock configuration.
#
# The dock is provided by an extension. Dash to Dock and Ubuntu Dock share the
# same schema, but key sets differ between versions, so every key is checked
# before it is written.

uf_dock_schema() {
  local schema
  for schema in \
    "org.gnome.shell.extensions.dash-to-dock" \
    "org.gnome.shell.extensions.ubuntu-dock"; do
    if uf_gs_schema_exists "$schema"; then
      printf '%s\n' "$schema"
      return 0
    fi
  done
  return 1
}

# uf_dock_set SCHEMA KEY VALUE LABEL -- only writes existing keys.
uf_dock_set() {
  local schema="$1" key="$2" value="$3" label="$4"
  if uf_gs_key_exists "$schema" "$key"; then
    uf_gs_set "$schema" "$key" "$value" "$label"
  else
    uf_debug "Dock key not available in ${schema}: ${key}"
  fi
}

# uf_dock_apply -- install/configure the dock extension.
uf_dock_apply() {
  local schema position size

  if ! uf_conf_bool "dock.enabled" true; then
    uf_skip "Dock disabled in configuration."
    return 0
  fi

  local guard_rc=0
  uf_ext_component_guard "dock" || guard_rc=$?
  if [ "$guard_rc" -eq 2 ]; then
    uf_warn "Dock extension unavailable; skipping dock configuration."
    return 2
  elif [ "$guard_rc" -ne 0 ]; then
    uf_warn "Dock extension could not be enabled; skipping dock configuration."
    return 1
  fi

  if ! schema="$(uf_dock_schema)"; then
    uf_warn "Dash to Dock settings schema was not found; log out and back in, then run 'ubuntuify install --component dock'."
    return 2
  fi

  position="$(uf_conf dock.position left)"
  size="$(uf_conf_int 'dock.icon_size' 48 16 128)"

  uf_dock_set "$schema" dock-position "'${position}'" "Dock position"
  uf_dock_set "$schema" dash-max-icon-size "$size" "Dock icon size"
  uf_dock_set "$schema" extend-height "$(uf_conf_bool dock.extend_height true && printf true || printf false)" "Dock full height"
  uf_dock_set "$schema" dock-fixed "$(uf_conf_bool dock.fixed true && printf true || printf false)" "Dock always visible"
  uf_dock_set "$schema" autohide "$(uf_conf_bool dock.autohide false && printf true || printf false)" "Dock autohide"
  uf_dock_set "$schema" intellihide "$(uf_conf_bool dock.intellihide false && printf true || printf false)" "Dock intelligent hide"
  uf_dock_set "$schema" show-favorites "$(uf_conf_bool dock.show_favorites true && printf true || printf false)" "Dock favorites"
  uf_dock_set "$schema" show-running "$(uf_conf_bool dock.show_running true && printf true || printf false)" "Dock running indicators"
  uf_dock_set "$schema" show-trash "$(uf_conf_bool dock.show_trash true && printf true || printf false)" "Dock trash"
  uf_dock_set "$schema" show-mounts "$(uf_conf_bool dock.show_mounts true && printf true || printf false)" "Dock mounted drives"
  uf_dock_set "$schema" show-show-apps-button "$(uf_conf_bool dock.show_apps_button true && printf true || printf false)" "Dock applications button"
  uf_dock_set "$schema" show-apps-at-top "$(uf_conf_bool dock.apps_button_at_top true && printf true || printf false)" "Dock applications button position"
  uf_dock_set "$schema" multi-monitor "$(uf_conf_bool dock.multi_monitor false && printf true || printf false)" "Dock on all monitors"
  uf_dock_set "$schema" click-action "'$(uf_conf dock.click_action minimize-or-previews)'" "Dock click action"
  uf_dock_set "$schema" scroll-action "'$(uf_conf dock.scroll_action cycle-windows)'" "Dock scroll action"
  uf_dock_set "$schema" background-opacity "$(uf_conf dock.opacity 0.8)" "Dock background opacity"
  uf_dock_set "$schema" custom-theme-shrink "$(uf_conf_bool dock.theme_shrink true && printf true || printf false)" "Dock theme shrink"

  uf_ok "Dock configured (${position}, ${size}px)"
  return 0
}

# uf_dock_status -- one-line dock summary for status/score.
uf_dock_status() {
  local schema position size
  if ! schema="$(uf_dock_schema)"; then
    printf 'not installed'
    return 0
  fi
  position="$(uf_gs_value "$schema" dock-position left)"
  size="$(uf_gs_value "$schema" dash-max-icon-size '?')"
  printf '%s, %spx' "$position" "$size"
}
