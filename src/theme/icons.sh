# shellcheck shell=bash
# Yaru icon theme.

# uf_icon_theme_exists NAME
uf_icon_theme_exists() {
  local name="$1" base
  for base in "/usr/share/icons" "${HOME}/.icons" "${HOME}/.local/share/icons"; do
    [ -f "${base}/${name}/index.theme" ] && return 0
  done
  return 1
}

# uf_icons_apply -- configure the Yaru icon theme.
uf_icons_apply() {
  local name dark_name

  if uf_conf_bool "icons.install" true && ! uf_icon_theme_exists "Yaru"; then
    if ! uf_pkg_install_first "yaru-theme;yaru-icon-theme" "Yaru icons"; then
      uf_warn "Yaru icon theme is unavailable; keeping the current icon theme."
      return 1
    fi
  fi

  if uf_theme_is_dark; then
    dark_name="$(uf_conf icons.dark_name Yaru-dark)"
    if uf_icon_theme_exists "$dark_name"; then
      name="$dark_name"
    else
      name="$(uf_conf icons.name Yaru)"
    fi
  else
    name="$(uf_conf icons.name Yaru)"
  fi

  if ! uf_icon_theme_exists "$name"; then
    uf_warn "Icon theme ${name} was not found; keeping the current icon theme."
    return 1
  fi

  uf_setting org.gnome.desktop.interface icon-theme "'${name}'" "Icon theme"
  return 0
}
