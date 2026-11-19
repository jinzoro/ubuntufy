# shellcheck shell=bash
# Appearance settings: accent colour, clock format, interaction polish.

# uf_appearance_apply -- apply Ubuntu-like appearance defaults.
uf_appearance_apply() {
  local accent clock_24h
  accent="$(uf_conf appearance.accent orange)"
  clock_24h="$(uf_conf appearance.clock_24h false)"

  uf_setting org.gnome.desktop.interface accent-color "'${accent}'" "Accent colour"

  if uf_is_true "$clock_24h"; then
    uf_setting org.gnome.desktop.interface clock-format "'24h'" "Clock format"
  fi

  # Ubuntu uses the same wallpaper on the lock screen as on the desktop.
  if uf_gs_schema_exists org.gnome.desktop.screensaver; then
    uf_debug "Lock screen shares the desktop background on GNOME"
  fi
  return 0
}
