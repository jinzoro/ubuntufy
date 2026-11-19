# shellcheck shell=bash
# Ubuntu/Yaru sound theme (GNOME-level only; system audio is untouched).

uf_sound_theme_exists() {
  local theme="$1"
  [ -d "/usr/share/sounds/${theme}" ]
}

uf_sound_apply() {
  local theme
  if ! uf_conf_bool "sound.enabled" true; then
    uf_skip "Sound theme disabled in configuration."
    return 0
  fi

  theme="$(uf_conf sound.theme Yaru)"
  if ! uf_sound_theme_exists "$theme"; then
    uf_pkg_install_first "yaru-theme;yaru-sound-theme" "Yaru sound theme" >/dev/null || true
  fi
  if ! uf_sound_theme_exists "$theme"; then
    uf_warn "Yaru sound theme is not installed; keeping the current sound theme."
    return 2
  fi

  uf_setting org.gnome.desktop.sound theme "'${theme}'" "Sound theme"
  uf_setting org.gnome.desktop.sound event-sounds true "Event sounds"
  return 0
}
