# shellcheck shell=bash
# Cursor theme.

# uf_cursor_theme_exists NAME
uf_cursor_theme_exists() {
  local name="$1" base
  for base in "/usr/share/icons" "${HOME}/.icons" "${HOME}/.local/share/icons"; do
    [ -d "${base}/${name}/cursors" ] && return 0
  done
  return 1
}

# uf_cursor_apply -- configure the Yaru cursor theme and size.
uf_cursor_apply() {
  local name size
  name="$(uf_conf cursor.name Yaru)"
  size="$(uf_conf_int "cursor.size" 24 16 128)"

  if uf_conf_bool "cursor.install" true && ! uf_cursor_theme_exists "$name"; then
    # Fedora packages Yaru GTK/icons/sound themes; cursor assets may be absent.
    if ! uf_pkg_install_first "yaru-theme;yaru-icon-theme" "Yaru cursor theme"; then
      uf_warn "Cursor theme ${name} is not available on Fedora; keeping the current cursor."
      return 2
    fi
  fi

  if ! uf_cursor_theme_exists "$name"; then
    uf_warn "Cursor theme ${name} was not found on this system; keeping the current cursor."
    uf_info "Fedora's Yaru packages do not ship the Yaru cursor theme. This is a known upstream gap."
    return 2
  fi

  uf_setting org.gnome.desktop.interface cursor-theme "'${name}'" "Cursor theme"
  uf_setting org.gnome.desktop.interface cursor-size "$size" "Cursor size"
  return 0
}
