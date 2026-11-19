# shellcheck shell=bash
# Ubuntu-like keyboard shortcuts.
#
# Rules:
#   * existing custom bindings are backed up with the rest of the profile;
#   * a shortcut whose current value differs is never replaced silently;
#   * accelerators already used by custom shortcuts are reported and skipped;
#   * the automation default is to keep whatever the user already has.

# uf_shortcut_is_empty VALUE -- true for an unset GVariant string array.
uf_shortcut_is_empty() {
  case "${1:-}" in
    '' | '[]' | '@as []') return 0 ;;
    *) return 1 ;;
  esac
}

# uf_shortcut_bindings VALUE -- one accelerator per line.
uf_shortcut_bindings() {
  local value="${1:-}"
  [ -n "$value" ] || return 0
  python3 "${UF_SRC}/core/gvariant.py" list-get "$value" 2>/dev/null || true
}

# uf_shortcuts_custom_conflict VALUE -- print a custom keybinding path that
# already uses any accelerator in VALUE.
uf_shortcuts_custom_conflict() {
  local desired="$1" raw paths="" path schema current binding
  raw="$(uf_gs_get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || true)"
  [ -n "$raw" ] || return 1
  paths="$(python3 "${UF_SRC}/core/gvariant.py" list-get "$raw" 2>/dev/null || true)"
  [ -n "$paths" ] || return 1

  while IFS= read -r path; do
    [ -n "$path" ] || continue
    schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path}"
    current="$(gsettings get "$schema" binding 2>/dev/null || true)"
    [ -n "$current" ] || continue
    current="${current#\'}"
    current="${current%\'}"
    [ -n "$current" ] || continue
    if uf_shortcut_bindings "$desired" | grep -qxF -- "$current"; then
      printf '%s\n' "$path"
      return 0
    fi
  done < <(printf '%s\n' "$paths")
  return 1
}

# uf_shortcut_set SCHEMA KEY VALUE LABEL
uf_shortcut_set() {
  local schema="$1" key="$2" value="$3" label="$4" current on_conflict conflict

  if ! uf_gs_key_exists "$schema" "$key"; then
    uf_skip "Shortcut unavailable on this GNOME version: ${schema} ${key} (${label})"
    return 0
  fi

  current="$(uf_gs_get "$schema" "$key" 2>/dev/null || true)"
  if [ "$current" = "$value" ]; then
    uf_debug "Shortcut already correct: ${label}"
    return 0
  fi

  if conflict="$(uf_shortcuts_custom_conflict "$value")"; then
    uf_warn "${label}: ${value} is already used by the custom shortcut ${conflict}."
    uf_info "Skipping ${label} to avoid a keyboard shortcut conflict."
    return 0
  fi

  if ! uf_shortcut_is_empty "$current"; then
    on_conflict="$(uf_conf shortcuts.on_conflict keep)"
    case "$on_conflict" in
      keep)
        uf_info "Keeping existing ${label} shortcut (${current})."
        return 0
        ;;
      ask)
        if ! uf_confirm "${label} is currently ${current}. Replace it with the Ubuntu shortcut ${value}?" n; then
          uf_info "Keeping existing ${label} shortcut."
          return 0
        fi
        ;;
    esac
  fi

  uf_gs_set "$schema" "$key" "$value" "Shortcut: ${label}"
  return 0
}

# uf_shortcuts_apply -- apply the Ubuntu shortcut set.
uf_shortcuts_apply() {
  if ! uf_conf_bool "ubuntu_shortcuts" true; then
    uf_skip "Ubuntu shortcuts disabled in configuration."
    return 0
  fi

  if uf_conf_bool "shortcuts.show_apps" true; then
    uf_shortcut_set org.gnome.shell.keybindings toggle-application-view "['<Super>a']" "Show applications (Super+A)"
  fi
  if uf_conf_bool "shortcuts.home" true; then
    uf_shortcut_set org.gnome.settings-daemon.plugins.media-keys home "['<Super>e']" "Home folder (Super+E)"
  fi
  if uf_conf_bool "shortcuts.lock" true; then
    uf_shortcut_set org.gnome.settings-daemon.plugins.media-keys screensaver "['<Super>l']" "Lock screen (Super+L)"
  fi
  if uf_conf_bool "shortcuts.terminal" true; then
    uf_shortcut_set org.gnome.settings-daemon.plugins.media-keys terminal "['<Control><Alt>t']" "Terminal (Ctrl+Alt+T)"
  fi

  if uf_conf_bool "shortcuts.tiling" true; then
    uf_shortcut_set org.gnome.desktop.wm.keybindings maximize "['<Super>Up']" "Maximize window (Super+Up)"
    uf_shortcut_set org.gnome.desktop.wm.keybindings unmaximize "['<Super>Down']" "Restore window (Super+Down)"
    uf_shortcut_set org.gnome.mutter.keybindings toggle-tiled-left "['<Super>Left']" "Tile left (Super+Left)"
    uf_shortcut_set org.gnome.mutter.keybindings toggle-tiled-right "['<Super>Right']" "Tile right (Super+Right)"
  fi

  uf_shortcut_set org.gnome.desktop.wm.keybindings switch-to-workspace-left \
    "['<Control><Alt>Left', '<Super>Page_Up']" "Previous workspace (Ctrl+Alt+Left)"
  uf_shortcut_set org.gnome.desktop.wm.keybindings switch-to-workspace-right \
    "['<Control><Alt>Right', '<Super>Page_Down']" "Next workspace (Ctrl+Alt+Right)"
  uf_shortcut_set org.gnome.desktop.wm.keybindings move-to-workspace-left \
    "['<Control><Alt><Shift>Left', '<Super><Shift>Page_Up']" "Move window to previous workspace"
  uf_shortcut_set org.gnome.desktop.wm.keybindings move-to-workspace-right \
    "['<Control><Alt><Shift>Right', '<Super><Shift>Page_Down']" "Move window to next workspace"

  return 0
}
