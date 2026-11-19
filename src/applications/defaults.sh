# shellcheck shell=bash
# Default applications and MIME associations.
#
# Only applications that are actually installed are configured.

# uf_xdg_set_default COMMAND ARG... -- run an xdg tool or report a skip.
uf_xdg_default_web_browser() {
  local desktop="$1"
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would set default web browser to ${desktop}"
    return 0
  fi
  if ! uf_have xdg-settings; then
    uf_skip "xdg-settings is not installed; default browser not changed."
    return 0
  fi
  if xdg-settings set default-web-browser "$desktop" >/dev/null 2>&1; then
    uf_ok "Default web browser: ${desktop}"
  else
    uf_warn "Could not set the default web browser to ${desktop}."
  fi
}

# uf_defaults_apply -- configure sensible Ubuntu-like defaults.
uf_defaults_apply() {
  if ! uf_conf_bool "defaults.enabled" true; then
    uf_skip "Default application configuration disabled."
    return 0
  fi

  local browser
  if browser="$(uf_desktop_file_resolve 'firefox.desktop|firefox_firefox.desktop|org.mozilla.firefox.desktop')"; then
    uf_xdg_default_web_browser "$browser"
  else
    uf_skip "Firefox is not installed; default browser unchanged."
  fi

  local file_manager
  if file_manager="$(uf_desktop_file_resolve 'org.gnome.Nautilus.desktop')"; then
    if [ "$UF_DRY_RUN" -eq 1 ]; then
      uf_dry "Would set ${file_manager} as the default file manager"
    elif uf_have xdg-mime; then
      if xdg-mime default "$file_manager" inode/directory >/dev/null 2>&1; then
        uf_ok "Default file manager: ${file_manager}"
      else
        uf_warn "Could not set the default file manager."
      fi
    else
      uf_skip "xdg-mime is not installed; default file manager not changed."
    fi
  else
    uf_skip "GNOME Files is not installed; default file manager unchanged."
  fi

  # Some legacy applications read the terminal default from this schema.
  if uf_have kgx && uf_gs_key_exists org.gnome.desktop.default-applications.terminal exec; then
    uf_setting org.gnome.desktop.default-applications.terminal exec "'kgx'" "Default terminal"
  fi
  return 0
}
