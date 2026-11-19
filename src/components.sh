# shellcheck shell=bash
# Component registry and profiles.
#
# A component is a self-contained unit of the Ubuntu experience. The engine
# applies components in this order so that extensions exist before their
# settings are written.

UF_COMPONENT_ORDER=(
  appearance
  theme
  icons
  cursor
  fonts
  overview
  panel
  dock
  desktop-icons
  tray
  tiling
  shortcuts
  windows
  workspaces
  notifications
  power
  nautilus
  favorites
  wallpaper
  sound
  default-apps
  plymouth
  gdm
)

# uf_component_title NAME -- human readable name.
uf_component_title() {
  case "$1" in
    appearance) printf 'Appearance' ;;
    theme) printf 'Yaru theme' ;;
    icons) printf 'Yaru icons' ;;
    cursor) printf 'Cursor theme' ;;
    fonts) printf 'Ubuntu fonts' ;;
    overview) printf 'Overview and hot corner' ;;
    panel) printf 'Top panel' ;;
    dock) printf 'Ubuntu dock' ;;
    desktop-icons) printf 'Desktop icons' ;;
    tray) printf 'System tray (AppIndicator)' ;;
    tiling) printf 'Tiling Assistant' ;;
    shortcuts) printf 'Keyboard shortcuts' ;;
    windows) printf 'Window behaviour' ;;
    workspaces) printf 'Workspaces' ;;
    notifications) printf 'Notifications' ;;
    power) printf 'Power behaviour' ;;
    nautilus) printf 'GNOME Files' ;;
    favorites) printf 'Application favorites' ;;
    wallpaper) printf 'Wallpaper' ;;
    sound) printf 'Sound theme' ;;
    default-apps) printf 'Default applications' ;;
    plymouth) printf 'Plymouth boot branding (optional)' ;;
    gdm) printf 'GDM login background (optional)' ;;
    *) printf '%s' "$1" ;;
  esac
}

# uf_component_normalize NAME -- resolve aliases.
uf_component_normalize() {
  local name
  name="$(uf_lower "$1")"
  name="${name//_/-}"
  case "$name" in
    ding | desktopicons | desktop-icon) name="desktop-icons" ;;
    defaults | applications) name="default-apps" ;;
    shortcut | keyboard) name="shortcuts" ;;
    appindicator | app-indicator) name="tray" ;;
    gnome-behavior | behaviour) name="windows" ;;
    shell-theme | shell) name="theme" ;;
    font) name="fonts" ;;
    icon) name="icons" ;;
  esac
  printf '%s\n' "$name"
}

# uf_component_exists NAME
uf_component_exists() {
  local component
  for component in "${UF_COMPONENT_ORDER[@]}"; do
    [ "$component" = "$1" ] && return 0
  done
  return 1
}

# uf_component_aliases -- help text for component names.
uf_component_aliases() {
  printf 'defaults -> default-apps, ding -> desktop-icons, appindicator -> tray, gnome-behavior -> windows'
}

# uf_component_run NAME -- execute one component. Returns its status.
uf_component_run() {
  local component="$1"
  if ! uf_component_exists "$component"; then
    uf_error "Unknown component: ${component}"
    return 1
  fi

  case "$component" in
    appearance) uf_appearance_apply ;;
    theme) uf_theme_apply ;;
    icons) uf_icons_apply ;;
    cursor) uf_cursor_apply ;;
    fonts) uf_fonts_apply ;;
    overview) uf_overview_apply ;;
    panel) uf_panel_apply ;;
    dock) uf_dock_apply ;;
    desktop-icons) uf_desktop_icons_apply ;;
    tray) uf_tray_apply ;;
    tiling) uf_tiling_apply ;;
    shortcuts) uf_shortcuts_apply ;;
    windows) uf_windows_apply ;;
    workspaces) uf_workspaces_apply ;;
    notifications) uf_notifications_apply ;;
    power) uf_power_apply ;;
    nautilus) uf_nautilus_apply ;;
    favorites) uf_favorites_apply ;;
    wallpaper) uf_wallpaper_apply ;;
    sound) uf_sound_apply ;;
    default-apps) uf_defaults_apply ;;
    plymouth) uf_plymouth_apply ;;
    gdm) uf_gdm_apply ;;
    *)
      uf_error "Component not implemented: ${component}"
      return 1
      ;;
  esac
}

# uf_profile_components PROFILE -- print the components for a profile.
uf_profile_components() {
  local profile="$1"
  case "$profile" in
    minimal)
      printf '%s\n' theme icons cursor fonts wallpaper
      ;;
    full | dark)
      printf '%s\n' theme icons cursor fonts appearance overview panel dock \
        desktop-icons tray tiling shortcuts windows workspaces notifications \
        power nautilus favorites wallpaper sound default-apps
      ;;
    classic)
      printf '%s\n' theme icons cursor fonts appearance overview panel dock \
        desktop-icons tray shortcuts windows workspaces nautilus favorites \
        wallpaper sound default-apps
      ;;
    custom)
      local entry
      while IFS= read -r entry; do
        [ -n "$entry" ] || continue
        uf_component_normalize "$entry"
      done < <(uf_split_list ';' "$(uf_conf custom.components '')")
      ;;
    *)
      return 1
      ;;
  esac
}

# uf_profile_validate PROFILE -- true for a known profile, with custom checked.
uf_profile_validate() {
  local profile="$1" component
  case "$profile" in
    full | minimal | dark | classic) return 0 ;;
    custom)
      local list
      list="$(uf_profile_components custom)"
      if [ -z "$list" ]; then
        uf_error "Profile 'custom' requires custom.components in ${UF_USER_CONFIG}."
        return 1
      fi
      while IFS= read -r component; do
        if ! uf_component_exists "$component"; then
          uf_error "Unknown component in custom.components: ${component}"
          return 1
        fi
      done <<<"$list"
      return 0
      ;;
    *)
      uf_error "Unknown profile '${profile}'. Available: full, minimal, dark, classic, custom."
      return 1
      ;;
  esac
}

# uf_profile_title PROFILE
uf_profile_title() {
  case "$1" in
    full) printf 'Ubuntu Full' ;;
    minimal) printf 'Ubuntu Minimal' ;;
    dark) printf 'Ubuntu Dark' ;;
    classic) printf 'Ubuntu Classic' ;;
    custom) printf 'Ubuntu Custom' ;;
    *) printf '%s' "$1" ;;
  esac
}

# uf_profile_switch_help -- list profiles for help output.
uf_profile_switch_help() {
  cat <<'EOF'
Profiles:
  full      Everything supported by Ubuntuify (recommended)
  minimal   Visual changes only: Yaru, icons, cursor, fonts, wallpaper
  dark      Full profile with Ubuntu dark appearance
  classic   Conservative Ubuntu layout without tiling
  custom    Components listed in custom.components
EOF
}
