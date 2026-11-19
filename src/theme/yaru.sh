# shellcheck shell=bash
# Yaru GTK and GNOME Shell theme.

# uf_theme_dir_exists NAME -- true when a GTK theme is installed.
uf_theme_dir_exists() {
  local name="$1" base
  for base in "/usr/share/themes" "${HOME}/.themes" "${HOME}/.local/share/themes"; do
    if [ -d "${base}/${name}/gtk-3.0" ] || [ -d "${base}/${name}/gtk-4.0" ]; then
      return 0
    fi
  done
  return 1
}

# uf_theme_shell_exists NAME -- true when a GNOME Shell theme is installed.
uf_theme_shell_exists() {
  local name="$1" base
  for base in "/usr/share/themes" "${HOME}/.themes" "${HOME}/.local/share/themes"; do
    if [ -d "${base}/${name}/gnome-shell" ]; then
      return 0
    fi
  done
  return 1
}

# uf_theme_package -- install the Yaru theme package when needed.
uf_theme_package() {
  if uf_theme_dir_exists "Yaru"; then
    uf_ok "Yaru theme already installed"
    return 0
  fi
  uf_pkg_install_first "yaru-theme;yaru-gtk3-theme" "Yaru theme" || return $?
  if uf_theme_dir_exists "Yaru"; then
    return 0
  fi
  uf_warn "Yaru theme package is installed but /usr/share/themes/Yaru was not found."
  return 1
}

# uf_theme_is_dark -- true when the requested scheme is dark.
uf_theme_is_dark() {
  local scheme
  scheme="$(uf_conf color_scheme default)"
  case "$scheme" in
    prefer-dark | dark) return 0 ;;
    *) return 1 ;;
  esac
}

# uf_theme_apply -- configure GTK, color scheme and, when available, the
# GNOME Shell theme.
uf_theme_apply() {
  local dark=0 gtk_theme shell_theme

  if uf_conf_bool "theme.install" true; then
    uf_theme_package || return 1
  fi

  if uf_theme_is_dark; then
    dark=1
  fi

  if [ "$dark" -eq 1 ]; then
    gtk_theme="$(uf_conf theme.dark_name Yaru-dark)"
    shell_theme="$(uf_conf theme.shell_dark_name Yaru-dark)"
  else
    gtk_theme="$(uf_conf theme.name Yaru)"
    shell_theme="$(uf_conf theme.shell_name Yaru)"
  fi

  if ! uf_theme_dir_exists "$gtk_theme"; then
    if uf_theme_dir_exists "Yaru"; then
      uf_warn "Theme ${gtk_theme} is unavailable; falling back to Yaru."
      gtk_theme="Yaru"
    else
      uf_warn "No Yaru GTK theme found; keeping the current GTK theme."
      return 1
    fi
  fi

  uf_setting org.gnome.desktop.interface gtk-theme "'${gtk_theme}'" "GTK theme"
  uf_setting org.gnome.desktop.wm.preferences theme "'${gtk_theme}'" "Window theme"

  if [ "$dark" -eq 1 ]; then
    uf_setting org.gnome.desktop.interface color-scheme "'prefer-dark'" "Dark color scheme"
  else
    uf_setting org.gnome.desktop.interface color-scheme "'default'" "Light color scheme"
  fi

  uf_theme_shell_apply "$shell_theme"
  return 0
}

# uf_theme_shell_apply THEME -- GNOME Shell theme via the User Themes extension.
uf_theme_shell_apply() {
  local theme="$1"
  if ! uf_theme_shell_exists "$theme"; then
    if uf_theme_shell_exists "Yaru"; then
      theme="Yaru"
    else
      uf_warn "GNOME Shell Yaru theme is not installed; leaving the default Fedora shell theme."
      uf_info "Fedora ships Yaru GTK themes; the shell theme is packaged as gnome-shell-theme-yaru when available."
      return 0
    fi
  fi

  if ! uf_ext_resolve "user-theme" >/dev/null 2>&1; then
    uf_ext_ensure "user-theme" || {
      uf_warn "The User Themes extension is unavailable; cannot apply the Yaru GNOME Shell theme."
      return 0
    }
  else
    local uuid
    uuid="$(uf_ext_resolve "user-theme")"
    uf_ext_enable "$uuid" "User Themes" || true
  fi

  if uf_gs_schema_exists org.gnome.shell.extensions.user-theme; then
    uf_setting org.gnome.shell.extensions.user-theme name "'${theme}'" "GNOME Shell theme"
  else
    uf_skip "User Themes settings schema is unavailable; GNOME Shell theme not changed."
  fi
  return 0
}
