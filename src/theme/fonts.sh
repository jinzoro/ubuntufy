# shellcheck shell=bash
# Ubuntu font configuration.
#
# Fedora does not currently package the Ubuntu font family. Ubuntuify detects
# the font, tries Fedora-compatible packages and otherwise leaves the user's
# fonts untouched (documented fallback) instead of breaking font rendering.

# uf_font_family_installed FAMILY -- true when fontconfig knows the family.
uf_font_family_installed() {
  local family="$1" output families
  uf_have fc-list || return 1
  output="$(fc-list -f '%{family}\n' 2>/dev/null || true)"
  [ -n "$output" ] || return 1
  families="$(printf '%s\n' "$output" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  grep -qx -- "$family" <<<"$families"
}

# uf_fonts_ensure -- try to install the Ubuntu font family on Fedora.
uf_fonts_ensure() {
  local family="$1"
  uf_font_family_installed "$family" && return 0
  if ! uf_conf_bool "fonts.install" true; then
    return 1
  fi
  uf_pkg_install_first "ubuntu-font-family;google-ubuntu-font-family;fonts-ubuntu" "Ubuntu fonts" >/dev/null || true
  uf_font_family_installed "$family"
}

# uf_fonts_apply -- configure Ubuntu fonts when they are available.
uf_fonts_apply() {
  local family mono size mono_size titlebar_size
  family="$(uf_conf fonts.family Ubuntu)"
  mono="$(uf_conf fonts.monospace_family 'Ubuntu Mono')"
  size="$(uf_conf_int 'fonts.size' 11 6 48)"
  mono_size="$(uf_conf_int 'fonts.monospace_size' 13 6 48)"
  titlebar_size="$(uf_conf_int 'fonts.titlebar_size' 11 6 48)"

  if ! uf_fonts_ensure "$family"; then
    uf_warn "Ubuntu fonts are not available from Fedora repositories; keeping the current fonts."
    uf_info "This is a Fedora packaging gap, not a failure. The rest of the profile is unaffected."
    return 2
  fi

  uf_setting org.gnome.desktop.interface font-name "'${family} ${size}'" "Interface font"
  uf_setting org.gnome.desktop.interface document-font-name "'${family} ${size}'" "Document font"
  uf_setting org.gnome.desktop.wm.preferences titlebar-font "'${family} Bold ${titlebar_size}'" "Titlebar font"

  if uf_font_family_installed "$mono"; then
    uf_setting org.gnome.desktop.interface monospace-font-name "'${mono} ${mono_size}'" "Monospace font"
  else
    uf_skip "Ubuntu Mono is not installed; keeping the current monospace font."
  fi
  return 0
}
