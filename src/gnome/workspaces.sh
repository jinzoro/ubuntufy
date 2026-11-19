# shellcheck shell=bash
# Workspace behaviour.

uf_workspaces_apply() {
  local dynamic count
  dynamic="$(uf_conf workspaces.dynamic true)"

  if uf_is_true "$dynamic"; then
    uf_setting org.gnome.mutter dynamic-workspaces true "Dynamic workspaces"
  else
    count="$(uf_conf_int 'workspaces.count' 4 1 32)"
    uf_setting org.gnome.mutter dynamic-workspaces false "Fixed workspaces"
    uf_setting org.gnome.desktop.wm.preferences num-workspaces "$count" "Workspace count"
  fi

  if uf_conf_bool "workspaces.only_primary" true; then
    uf_setting org.gnome.shell.overrides workspaces-only-on-primary true "Workspaces on primary monitor"
  fi

  # Ubuntu uses horizontal workspace switching; vertical layouts are not exposed
  # through a stable GSettings key across supported GNOME versions.
  uf_debug "Workspace layout uses the GNOME default for this version."
  return 0
}
