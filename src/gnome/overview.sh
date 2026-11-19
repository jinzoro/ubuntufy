# shellcheck shell=bash
# Overview, hot corner and shell-level Ubuntu behaviour.

uf_overview_apply() {
  if uf_conf_bool "appearance.hot_corner" true; then
    uf_setting org.gnome.desktop.interface enable-hot-corners true "Activities hot corner"
  fi

  # Ubuntu enables its own and user extensions. Never leave them disabled.
  uf_setting org.gnome.shell disable-user-extensions false "User extensions allowed"

  # Ubuntu does not show the "Welcome to GNOME" tour on first login.
  if [ -n "${UF_GNOME_VERSION:-}" ] && uf_gs_key_exists org.gnome.shell welcome-dialog-last-shown-version; then
    uf_setting org.gnome.shell welcome-dialog-last-shown-version "'${UF_GNOME_VERSION}'" "Welcome dialog state"
  fi
  return 0
}
