# shellcheck shell=bash
# Window behaviour: buttons, focus policy, animations and edge tiling.

# uf_windows_reduced_motion -- true when the user asked for reduced motion.
uf_windows_reduced_motion() {
  local value
  value="$(uf_gs_get org.gnome.desktop.a11y.interface reduced-motion 2>/dev/null || true)"
  [ "$value" = "true" ]
}

uf_windows_apply() {
  local buttons

  buttons="$(uf_conf windows.buttons 'appmenu:minimize,maximize,close')"
  uf_setting org.gnome.desktop.wm.preferences button-layout "'${buttons}'" "Window buttons"

  uf_setting org.gnome.desktop.wm.preferences focus-mode "'$(uf_conf windows.focus_mode click)'" "Focus mode"
  uf_setting org.gnome.desktop.wm.preferences raise-on-click "$(uf_conf_bool windows.raise_on_click true && printf true || printf false)" "Raise on click"
  uf_setting org.gnome.desktop.wm.preferences auto-raise "$(uf_conf_bool windows.auto_raise false && printf true || printf false)" "Auto raise"
  uf_setting org.gnome.desktop.wm.preferences action-double-click-titlebar "'toggle-maximize'" "Double-click titlebar"

  if uf_conf_bool "windows.edge_tiling" true; then
    if uf_gs_key_exists org.gnome.mutter edge-tiling; then
      uf_setting org.gnome.mutter edge-tiling true "Edge tiling"
    elif uf_gs_key_exists org.gnome.shell.overrides edge-tiling; then
      uf_setting org.gnome.shell.overrides edge-tiling true "Edge tiling"
    else
      uf_skip "Edge tiling setting is unavailable on this GNOME version."
    fi
  fi

  if uf_conf_bool "windows.animations" true; then
    if uf_windows_reduced_motion; then
      uf_info "Reduced motion is enabled; leaving GNOME animations unchanged."
    else
      uf_setting org.gnome.desktop.interface enable-animations true "GNOME animations"
    fi
  fi

  return 0
}
