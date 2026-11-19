# shellcheck shell=bash
# ubuntuify status and the Ubuntu Experience score.

# uf_status_mark BOOL -- ✓ or ○.
uf_status_mark() {
  if uf_is_true "$1"; then
    uf_style green '✓'
  else
    uf_style dim '○'
  fi
}

# uf_status_mark_cmd COMMAND... -- ✓ when the command succeeds, ○ otherwise.
uf_status_mark_cmd() {
  if "$@" >/dev/null 2>&1; then
    uf_style green '✓'
  else
    uf_style dim '○'
  fi
}

# uf_status_is_yaru VALUE -- true when a theme name mentions Yaru.
uf_status_is_yaru() {
  case "${1:-}" in
    *Yaru*) return 0 ;;
  esac
  return 1
}

uf_status_wallpaper_ok() {
  case "$(uf_state_get wallpaper)" in
    *ubuntuify*) return 0 ;;
  esac
  return 1
}

uf_status_sound_ok() {
  [ "$(uf_gs_value org.gnome.desktop.sound theme '')" = "Yaru" ]
}

uf_status_nautilus_ok() {
  [ "$(uf_gs_value org.gnome.nautilus.preferences default-folder-viewer '')" = "list-view" ]
}

uf_status_shortcuts_ok() {
  [ "$(uf_status_shortcuts_pct)" -ge 50 ]
}

uf_status_plymouth_ok() {
  [ -d "$UF_PLYMOUTH_THEME_DIR" ]
}

uf_status_gdm_ok() {
  [ -f "$UF_GDM_PROFILE_FILE" ]
}

# uf_score_percent PASSED TOTAL
uf_score_percent() {
  local passed="$1" total="$2"
  [ "$total" -gt 0 ] || {
    printf '0'
    return
  }
  printf '%s' "$((passed * 100 / total))"
}

# uf_score_bar PERCENT -- ten block bar.
uf_score_bar() {
  local percent="$1" filled empty
  filled=$(((percent * 10 + 50) / 100))
  empty=$((10 - filled))
  printf '%s%s' "$(uf_repeat '█' "$filled")" "$(uf_repeat '░' "$empty")"
}

# uf_status_profile_label -- human readable profile name.
uf_status_profile_label() {
  case "${1:-}" in
    full) printf 'Ubuntu Full' ;;
    minimal) printf 'Ubuntu Minimal' ;;
    dark) printf 'Ubuntu Dark' ;;
    classic) printf 'Ubuntu Classic' ;;
    custom) printf 'Ubuntu Custom' ;;
    "") printf 'Not installed' ;;
    *) printf '%s' "$1" ;;
  esac
}

# uf_status_theme_category_pct -- share of theme checks that pass.
uf_status_theme_pct() {
  local passed=0 total=0 gtk icons cursor scheme
  gtk="$(uf_gs_value org.gnome.desktop.interface gtk-theme '')"
  icons="$(uf_gs_value org.gnome.desktop.interface icon-theme '')"
  cursor="$(uf_gs_value org.gnome.desktop.interface cursor-theme '')"
  scheme="$(uf_gs_value org.gnome.desktop.interface color-scheme '')"
  total=4
  case "$gtk" in *Yaru*) passed=$((passed + 1)) ;; esac
  case "$icons" in *Yaru*) passed=$((passed + 1)) ;; esac
  case "$cursor" in *Yaru*) passed=$((passed + 1)) ;; esac
  [ -n "$scheme" ] && passed=$((passed + 1))
  uf_score_percent "$passed" "$total"
}

# uf_status_dock_pct
uf_status_dock_pct() {
  local schema passed=0 total=4 position size enabled
  if ! schema="$(uf_dock_schema)"; then
    printf '0'
    return
  fi
  position="$(uf_gs_value "$schema" dock-position '')"
  size="$(uf_gs_value "$schema" dash-max-icon-size '0')"
  enabled="$(uf_status_extension_enabled "dock" && printf yes || printf no)"
  total=4
  [ "$position" = "left" ] && passed=$((passed + 1))
  [[ $size =~ ^[0-9]+$ ]] && [ "$size" -ge 40 ] && [ "$size" -le 64 ] && passed=$((passed + 1))
  uf_is_true "$enabled" && passed=$((passed + 1))
  uf_gs_is_set "$schema" show-running true && passed=$((passed + 1))
  uf_score_percent "$passed" "$total"
}

# uf_status_extension_enabled NAME
uf_status_extension_enabled() {
  local uuid
  uuid="$(uf_ext_resolve "$1" 2>/dev/null || true)"
  [ -n "$uuid" ] && uf_ext_is_enabled "$uuid"
}

# uf_status_desktop_icons_pct
uf_status_desktop_icons_pct() {
  local schema passed=0 total=3
  if ! schema="$(uf_ding_schema)"; then
    printf '0'
    return
  fi
  uf_gs_is_set "$schema" show-home true && passed=$((passed + 1))
  uf_gs_is_set "$schema" show-trash true && passed=$((passed + 1))
  uf_gs_is_set "$schema" show-volumes true && passed=$((passed + 1))
  uf_score_percent "$passed" "$total"
}

# uf_status_shortcuts_pct
uf_status_shortcuts_pct() {
  local passed=0 total=3
  uf_shortcut_is_set org.gnome.shell.keybindings toggle-application-view && passed=$((passed + 1))
  uf_shortcut_is_set org.gnome.settings-daemon.plugins.media-keys home && passed=$((passed + 1))
  uf_shortcut_is_set org.gnome.desktop.wm.keybindings maximize && passed=$((passed + 1))
  uf_shortcut_is_set org.gnome.mutter.keybindings toggle-tiled-left && passed=$((passed + 1))
  total=4
  uf_score_percent "$passed" "$total"
}

# uf_shortcut_is_set SCHEMA KEY -- true when the key holds a non-empty binding.
uf_shortcut_is_set() {
  local value
  value="$(uf_gs_get "$1" "$2" 2>/dev/null || true)"
  [ -n "$value" ] && ! uf_shortcut_is_empty "$value"
}

# uf_status_windows_pct
uf_status_windows_pct() {
  local passed=0 total=2 layout
  layout="$(uf_gs_value org.gnome.desktop.wm.preferences button-layout '')"
  case "$layout" in
    *minimize*maximize*close*) passed=$((passed + 1)) ;;
  esac
  [ "$(uf_gs_value org.gnome.desktop.wm.preferences focus-mode '')" = "click" ] && passed=$((passed + 1))
  uf_score_percent "$passed" "$total"
}

# uf_status_boot_pct
uf_status_boot_pct() {
  local passed=0 total=2
  [ -d "$UF_PLYMOUTH_THEME_DIR" ] && passed=$((passed + 1))
  [ -f "$UF_GDM_PROFILE_FILE" ] && passed=$((passed + 1))
  uf_score_percent "$passed" "$total"
}

# uf_status_score -- Ubuntu Experience score (UX indicator, not a benchmark).
uf_status_score() {
  local theme dock icons tray shortcuts windows boot overall
  theme="$(uf_status_theme_pct)"
  dock="$(uf_status_dock_pct)"
  icons="$(uf_status_desktop_icons_pct)"
  if uf_status_extension_enabled "tray"; then tray=100; else tray=0; fi
  shortcuts="$(uf_status_shortcuts_pct)"
  windows="$(uf_status_windows_pct)"
  boot="$(uf_status_boot_pct)"
  overall=$(((theme + dock + icons + tray + shortcuts + windows + boot) / 7))

  uf_section "Ubuntu Experience"
  printf '  %-18s %s %3d%%\n' "Theme" "$(uf_score_bar "$theme")" "$theme"
  printf '  %-18s %s %3d%%\n' "Dock" "$(uf_score_bar "$dock")" "$dock"
  printf '  %-18s %s %3d%%\n' "Desktop Icons" "$(uf_score_bar "$icons")" "$icons"
  printf '  %-18s %s %3d%%\n' "System Tray" "$(uf_score_bar "$tray")" "$tray"
  printf '  %-18s %s %3d%%\n' "Shortcuts" "$(uf_score_bar "$shortcuts")" "$shortcuts"
  printf '  %-18s %s %3d%%\n' "Window Behavior" "$(uf_score_bar "$windows")" "$windows"
  printf '  %-18s %s %3d%%\n' "Boot Experience" "$(uf_score_bar "$boot")" "$boot"
  printf '\n  %s %d%% Ubuntu-like\n' "$(uf_style bold 'Overall:')" "$overall"
  uf_style dim "  This score is a UX indicator, not a technical benchmark."
  return 0
}

# uf_status_show -- main status output.
uf_status_show() {
  uf_detect_all
  local profile gtk icons cursor scheme dock platform backup overall_mark
  profile="$(uf_state_get "profile" 2>/dev/null || true)"
  gtk="$(uf_gs_value org.gnome.desktop.interface gtk-theme 'unknown')"
  icons="$(uf_gs_value org.gnome.desktop.interface icon-theme 'unknown')"
  cursor="$(uf_gs_value org.gnome.desktop.interface cursor-theme 'unknown')"
  scheme="$(uf_gs_value org.gnome.desktop.interface color-scheme 'unknown')"
  dock="$(uf_dock_status)"
  platform="GNOME ${UF_GNOME_VERSION:-unknown} · ${UF_SESSION_TYPE}"
  backup="$(uf_backup_latest 2>/dev/null || true)"

  uf_section "Ubuntuify Status"
  printf '  %s\n' "$(uf_style bold 'Profile:')"
  printf '    %s\n\n' "$(uf_status_profile_label "$profile")"

  printf '  %s\n' "$(uf_style bold 'Theme:')"
  printf '    GTK:     %s\n' "$gtk"
  printf '    Icons:   %s\n' "$icons"
  printf '    Cursor:  %s\n' "$cursor"
  printf '    Scheme:  %s\n\n' "$scheme"

  printf '  %s\n' "$(uf_style bold 'Dock:')"
  printf '    %s\n\n' "$dock"

  printf '  %s\n' "$(uf_style bold 'Desktop Icons:')"
  printf '    %s\n\n' "$(uf_desktop_icons_status)"

  printf '  %s\n' "$(uf_style bold 'Tray:')"
  printf '    AppIndicator: %s\n\n' "$(uf_tray_status)"

  printf '  %s\n' "$(uf_style bold 'GNOME:')"
  printf '    %s\n\n' "$platform"

  printf '  %s\n' "$(uf_style bold 'Backup:')"
  printf '    %s\n\n' "${backup:-none}"

  if [ -n "$profile" ] && [ "$gtk" != "unknown" ] && uf_status_extension_enabled "tray"; then
    overall_mark="$(uf_style green 'Ubuntuified ✓')"
  else
    overall_mark="$(uf_style yellow 'Not fully Ubuntuified')"
  fi
  printf '  %s\n    %s\n' "$(uf_style bold 'Overall:')" "$overall_mark"
  return 0
}

# uf_status_components -- per-component report.
uf_status_components() {
  uf_detect_all
  uf_section "Components"

  printf '  %-20s %s\n' "Theme" "$(uf_status_mark_cmd uf_status_is_yaru "$(uf_gs_value org.gnome.desktop.interface gtk-theme '')")"
  printf '  %-20s %s\n' "Icons" "$(uf_status_mark_cmd uf_status_is_yaru "$(uf_gs_value org.gnome.desktop.interface icon-theme '')")"
  printf '  %-20s %s\n' "Cursor" "$(uf_status_mark_cmd uf_status_is_yaru "$(uf_gs_value org.gnome.desktop.interface cursor-theme '')")"
  printf '  %-20s %s\n' "Fonts" "$(uf_status_mark_cmd uf_font_family_installed "Ubuntu")"
  printf '  %-20s %s\n' "Dock" "$(uf_status_mark_cmd uf_status_extension_enabled "dock")"
  printf '  %-20s %s\n' "Desktop Icons" "$(uf_status_mark_cmd uf_status_extension_enabled "desktop-icons")"
  printf '  %-20s %s\n' "AppIndicator" "$(uf_status_mark_cmd uf_status_extension_enabled "tray")"
  printf '  %-20s %s\n' "Tiling" "$(uf_status_mark_cmd uf_status_extension_enabled "tiling")"
  printf '  %-20s %s\n' "Shortcuts" "$(uf_status_mark_cmd uf_status_shortcuts_ok)"
  printf '  %-20s %s\n' "Nautilus" "$(uf_status_mark_cmd uf_status_nautilus_ok)"
  printf '  %-20s %s\n' "Wallpaper" "$(uf_status_mark_cmd uf_status_wallpaper_ok)"
  printf '  %-20s %s\n' "Sound" "$(uf_status_mark_cmd uf_status_sound_ok)"
  printf '  %-20s %s\n' "Plymouth" "$(uf_status_mark_cmd uf_status_plymouth_ok)"
  printf '  %-20s %s\n' "GDM" "$(uf_status_mark_cmd uf_status_gdm_ok)"
  return 0
}
