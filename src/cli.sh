# shellcheck shell=bash
# CLI argument parsing and interactive menu.

# uf_banner -- project banner.
uf_banner() {
  cat <<'EOF'
╔══════════════════════════════════════════════╗
║              UBUNTUIFY FEDORA                ║
║   Ubuntu-like GNOME experience on Fedora      ║
╚══════════════════════════════════════════════╝
EOF
}

# uf_help_global
uf_help_global() {
  cat <<EOF
${UF_NAME} ${UF_VERSION}

Transform Fedora's GNOME desktop into a familiar Ubuntu-like experience
without replacing Fedora's repositories, package manager, kernel or OS identity.

Usage: ${UF_NAME} [command] [options]

Commands:
  install        Apply the Ubuntu experience
  uninstall      Remove Ubuntuify and restore the previous state
  restore        Restore a backup (default: most recent)
  update         Re-apply the installed profile after system updates
  status         Show the current configuration (--components, --score)
  doctor         Diagnose the system and Ubuntuify installation
  backup         Create a backup now
  profile        Switch between light and dark Yaru appearance
  reset          Reset only Ubuntuify-managed configuration
  defaults       Configure sensible default applications
  components     List available components
  config         Show effective configuration (--sample for a template)
  package        Show package state
  version        Show version
  help           Show help for a command

Global options:
  -v, --verbose            More detail
  -q, --quiet              Less detail
  --no-color               Disable color
  --dry-run                Show what would change without changing it
  -y, --yes                Non-interactive, accept prompts (implies no EGO fallback)
  --no-backup              Skip the automatic pre-install backup
  --backup-now             Force a fresh backup before installing
  --remove-packages        Remove packages installed by Ubuntuify on uninstall
  --profile <name>         Profile: full|minimal|dark|classic|custom
  --component <name>       Repeatable; apply/restore only this component
  --backup <id>            Restore a specific backup by ID
  --online-extensions      Allow extensions.gnome.org fallback
  --no-online-extensions   Never download extensions
  -h, --help               Show help

Examples:
  ${UF_NAME} install
  ${UF_NAME} install --profile minimal --dry-run
  ${UF_NAME} install --component dock
  ${UF_NAME} profile dark
  ${UF_NAME} restore --backup 20260101-120000
  ${UF_NAME} status --components
  ${UF_NAME} doctor
EOF
}

# uf_help_command NAME
uf_help_command() {
  case "${1:-}" in
    install)
      cat <<EOF
Usage: ${UF_NAME} install [options]

Apply the Ubuntu experience to this Fedora GNOME session.

Options:
  --profile <name>         full|minimal|dark|classic|custom
  --component <name>       Repeatable; apply only these components
  --dry-run                Show what would change
  --yes                    Non-interactive
  --no-backup              Skip the automatic backup
  --backup-now             Force a fresh backup
  --online-extensions      Allow extensions.gnome.org fallback
  --no-online-extensions   Never download extensions
EOF
      ;;
    uninstall)
      cat <<EOF
Usage: ${UF_NAME} uninstall [options]

Remove the Ubuntuify layer and restore the previous configuration.

Options:
  --yes             Non-interactive
  --dry-run         Show what would change
  --remove-packages Remove packages installed by Ubuntuify
EOF
      ;;
    restore)
      cat <<EOF
Usage: ${UF_NAME} restore [--backup <id>] [--component <name>]

Restore a backup. With no options, restores the most recent full backup.
EOF
      ;;
    update)
      cat <<EOF
Usage: ${UF_NAME} update

Re-apply the installed profile after system updates.
EOF
      ;;
    status)
      cat <<EOF
Usage: ${UF_NAME} status [--components] [--score]

Show the current configuration.
EOF
      ;;
    doctor)
      cat <<EOF
Usage: ${UF_NAME} doctor

Diagnose the system and Ubuntuify installation.
EOF
      ;;
    backup)
      cat <<EOF
Usage: ${UF_NAME} backup

Create a backup now.
EOF
      ;;
    profile)
      cat <<EOF
Usage: ${UF_NAME} profile light|dark|show

Switch the appearance between Ubuntu light and dark.
EOF
      ;;
    reset)
      cat <<EOF
Usage: ${UF_NAME} reset

Reset only Ubuntuify-managed configuration.
EOF
      ;;
    defaults)
      cat <<EOF
Usage: ${UF_NAME} defaults

Configure sensible default applications.
EOF
      ;;
    components)
      cat <<EOF
Usage: ${UF_NAME} components

List available components.
EOF
      ;;
    config)
      cat <<EOF
Usage: ${UF_NAME} config [--sample]

Show the effective configuration.
EOF
      ;;
    package|packages)
      cat <<EOF
Usage: ${UF_NAME} package state

Show package state.
EOF
      ;;
    *)
      uf_help_global
      ;;
  esac
}

# uf_pause -- wait for Enter if interactive.
uf_pause() {
  if [ -t 0 ]; then
    printf '\nPress Enter to continue...'
    read -r _ || true
  fi
}

# uf_interactive_menu -- top-level menu.
uf_interactive() {
  uf_runtime_init
  local choice
  while true; do
    printf '\n'
    uf_banner
    printf '\n'
    uf_style bold 'Interactive mode'
    printf '\n'
    local options=(
      "Install Ubuntu Experience"
      "Appearance (light/dark)"
      "Dock"
      "Desktop Icons"
      "System Tray (AppIndicator)"
      "GNOME Behaviour"
      "Keyboard Shortcuts"
      "Applications"
      "Boot and Login (Plymouth/GDM)"
      "Diagnostics"
      "Backup and Restore"
      "Remove Ubuntuify"
      "Exit"
    )
    uf_menu "Choose an option" "${options[@]}"
    read -r choice || choice=0
    case "$choice" in
      1)
        UF_OPT_PROFILE="full"
        UF_OPT_COMPONENTS=()
        uf_install
        uf_pause
        ;;
      2)
        uf_interactive_appearance
        uf_pause
        ;;
      3)
        uf_install_component "dock"
        uf_pause
        ;;
      4)
        uf_install_component "desktop-icons"
        uf_pause
        ;;
      5)
        uf_install_component "tray"
        uf_pause
        ;;
      6)
        uf_interactive_gnome
        uf_pause
        ;;
      7)
        uf_install_component "shortcuts"
        uf_pause
        ;;
      8)
        uf_interactive_apps
        uf_pause
        ;;
      9)
        uf_interactive_boot
        uf_pause
        ;;
      10)
        uf_interactive_diagnostics
        uf_pause
        ;;
      11)
        uf_interactive_backup
        uf_pause
        ;;
      12)
        uf_uninstall
        uf_pause
        ;;
      0|'')
        uf_info "Goodbye."
        return 0
        ;;
      *)
        uf_warn "Invalid choice: ${choice}"
        ;;
    esac
  done
}

uf_interactive_appearance() {
  local mode
  printf '1) Ubuntu light\n2) Ubuntu dark\n3) Configure appearance component only\n0) Cancel\n'
  read -r -p 'Choose: ' mode || return 0
  case "$mode" in
    1) uf_switch_appearance light ;;
    2) uf_switch_appearance dark ;;
    3) uf_install_component appearance ;;
    0) return 0 ;;
    *) uf_warn "Invalid choice" ;;
  esac
}

uf_interactive_gnome() {
  local choice
  printf '1) Apply all GNOME behaviour components\n2) Windows\n3) Workspaces\n4) Notifications\n5) Power\n6) Overview and hot corner\n7) Panel\n0) Cancel\n'
  read -r -p 'Choose: ' choice || return 0
  case "$choice" in
    1) UF_OPT_COMPONENTS=(overview panel windows workspaces notifications power); uf_install ;;
    2) uf_install_component windows ;;
    3) uf_install_component workspaces ;;
    4) uf_install_component notifications ;;
    5) uf_install_component power ;;
    6) uf_install_component overview ;;
    7) uf_install_component panel ;;
    0) return 0 ;;
    *) uf_warn "Invalid choice" ;;
  esac
}

uf_interactive_apps() {
  local choice
  printf '1) Apply all application components\n2) GNOME Files\n3) Favorites\n4) Default applications\n0) Cancel\n'
  read -r -p 'Choose: ' choice || return 0
  case "$choice" in
    1) UF_OPT_COMPONENTS=(nautilus favorites default-apps); uf_install ;;
    2) uf_install_component nautilus ;;
    3) uf_install_component favorites ;;
    4) uf_install_component default-apps ;;
    0) return 0 ;;
    *) uf_warn "Invalid choice" ;;
  esac
}

uf_interactive_boot() {
  local choice
  printf '1) Plymouth boot branding (opt-in, needs sudo)\n2) GDM login background (opt-in, needs sudo)\n0) Cancel\n'
  read -r -p 'Choose: ' choice || return 0
  case "$choice" in
    1) uf_install_component plymouth ;;
    2) uf_install_component gdm ;;
    0) return 0 ;;
    *) uf_warn "Invalid choice" ;;
  esac
}

uf_interactive_diagnostics() {
  local choice
  printf '1) Status\n2) Status (components)\n3) Status (score)\n4) Doctor\n0) Cancel\n'
  read -r -p 'Choose: ' choice || return 0
  case "$choice" in
    1) uf_status_show ;;
    2) uf_status_components ;;
    3) uf_status_score ;;
    4) uf_doctor ;;
    0) return 0 ;;
    *) uf_warn "Invalid choice" ;;
  esac
}

uf_interactive_backup() {
  local choice
  printf '1) Create backup\n2) Restore latest\n3) List backups\n0) Cancel\n'
  read -r -p 'Choose: ' choice || return 0
  case "$choice" in
    1) uf_backup_action ;;
    2) uf_restore_action "" ;;
    3) uf_backup_list ;;
    0) return 0 ;;
    *) uf_warn "Invalid choice" ;;
  esac
}

# uf_cli -- main entry point.
uf_cli() {
  local command="" rest=() want_help=0
  local positional=()

  # Detect help early.
  for arg in "$@"; do
    if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
      want_help=1
    fi
  done

  # Parse global options.
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        shift
        ;;
      -v|--verbose)
        UF_VERBOSE=1
        shift
        ;;
      -q|--quiet)
        UF_QUIET=1
        shift
        ;;
      --no-color)
        UF_NO_COLOR=1
        shift
        ;;
      --dry-run)
        UF_DRY_RUN=1
        shift
        ;;
      -y|--yes)
        UF_ASSUME_YES=1
        shift
        ;;
      --no-backup)
        UF_NO_BACKUP=1
        shift
        ;;
      --backup-now)
        UF_FORCE_BACKUP=1
        shift
        ;;
      --remove-packages)
        UF_REMOVE_PACKAGES=1
        shift
        ;;
      --profile)
        if [ $# -lt 2 ]; then uf_error "Missing argument for --profile"; return 2; fi
        UF_OPT_PROFILE="$2"
        shift 2
        ;;
      --profile=*)
        UF_OPT_PROFILE="${1#--profile=}"
        shift
        ;;
      --component)
        if [ $# -lt 2 ]; then uf_error "Missing argument for --component"; return 2; fi
        local item
        IFS=',' read -ra _items <<<"$2"
        for item in "${_items[@]}"; do
          [ -n "$item" ] && UF_OPT_COMPONENTS+=("$item")
        done
        shift 2
        ;;
      --component=*)
        item="${1#--component=}"
        IFS=',' read -ra _items <<<"$item"
        for item in "${_items[@]}"; do
          [ -n "$item" ] && UF_OPT_COMPONENTS+=("$item")
        done
        shift
        ;;
      --backup)
        if [ $# -lt 2 ]; then uf_error "Missing argument for --backup"; return 2; fi
        UF_OPT_BACKUP="$2"
        shift 2
        ;;
      --backup=*)
        UF_OPT_BACKUP="${1#--backup=}"
        shift
        ;;
      --online-extensions)
        UF_ONLINE_EXTENSIONS="yes"
        shift
        ;;
      --no-online-extensions)
        UF_ONLINE_EXTENSIONS="no"
        shift
        ;;
      --sample)
        UF_SAMPLE_CONFIG=1
        shift
        ;;
      --components)
        UF_STATUS_COMPONENTS=1
        shift
        ;;
      --score)
        UF_STATUS_SCORE=1
        shift
        ;;
      --)
        shift
        while [ $# -gt 0 ]; do positional+=("$1"); shift; done
        break
        ;;
      -*)
        uf_error "Unknown option: $1"
        return 2
        ;;
      *)
        if [ -z "$command" ]; then
          command="$1"
        else
          positional+=("$1")
        fi
        shift
        ;;
    esac
  done

  if [ "$want_help" -eq 1 ]; then
    if [ -z "$command" ]; then
      uf_help_global
    else
      uf_help_command "$command"
    fi
    return 0
  fi

  case "$command" in
    "" | help | profile | package | packages) ;;
    *)
      if [ "${#positional[@]}" -gt 0 ]; then
        uf_error "Unexpected argument: ${positional[0]}"
        return 2
      fi
      ;;
  esac

  case "$command" in
    "" )
      uf_interactive
      return $?
      ;;
    help)
      if [ "${#positional[@]}" -gt 0 ]; then
        uf_help_command "${positional[0]}"
      else
        uf_help_global
      fi
      return 0
      ;;
    version)
      printf '%s %s\n' "$UF_NAME" "$UF_VERSION"
      printf 'State schema: 1\n'
      return 0
      ;;
    install)
      uf_runtime_init || return 1
      uf_install
      return $?
      ;;
    uninstall)
      uf_runtime_init || return 1
      uf_uninstall
      return $?
      ;;
    restore)
      if [ "${#UF_OPT_COMPONENTS[@]}" -gt 0 ]; then
        UF_OPT_COMPONENT="$(uf_component_normalize "${UF_OPT_COMPONENTS[0]}")"
      fi
      uf_runtime_init || return 1
      uf_restore_action "$UF_OPT_BACKUP" "$UF_OPT_COMPONENT"
      return $?
      ;;
    update)
      uf_runtime_init || return 1
      uf_update
      return $?
      ;;
    status)
      uf_runtime_init --probe || return 1
      if [ "${UF_STATUS_COMPONENTS:-0}" -eq 1 ]; then
        uf_status_components
      elif [ "${UF_STATUS_SCORE:-0}" -eq 1 ]; then
        uf_status_score
      else
        uf_status_show
      fi
      return $?
      ;;
    doctor)
      uf_runtime_init --probe || return 1
      uf_doctor
      return $?
      ;;
    backup)
      uf_runtime_init || return 1
      uf_backup_action
      return $?
      ;;
    profile)
      uf_runtime_init || return 1
      if [ "${#positional[@]}" -eq 0 ]; then
        uf_info "Current profile: $(uf_state_get profile 2>/dev/null || printf unknown)"
        return 0
      fi
      case "${positional[0]}" in
        show)
          uf_info "Current profile: $(uf_state_get profile 2>/dev/null || printf unknown)"
          return 0
          ;;
        light)
          uf_switch_appearance light
          return $?
          ;;
        dark)
          uf_switch_appearance dark
          return $?
          ;;
        full|minimal|classic|custom)
          uf_profile_validate "${positional[0]}" || return 1
          UF_OPT_PROFILE="${positional[0]}"
          uf_install
          return $?
          ;;
        *)
          uf_error "Unknown profile: ${positional[0]}"
          return 2
          ;;
      esac
      ;;
    reset)
      uf_runtime_init || return 1
      uf_reset
      return $?
      ;;
    defaults)
      uf_runtime_init || return 1
      UF_OPT_COMPONENTS=(default-apps)
      uf_install
      return $?
      ;;
    components)
      uf_show_components
      return 0
      ;;
    config)
      if [ "${UF_SAMPLE_CONFIG:-0}" -eq 1 ]; then
        uf_config_sample
        return 0
      fi
      uf_runtime_init --probe || return 1
      uf_section "Effective configuration"
      uf_config_show
      if [ ! -f "$UF_CONFIG" ]; then
        uf_info "No user configuration yet. Create ${UF_CONFIG} or run '${UF_NAME} config --sample'."
      fi
      return 0
      ;;
    package|packages)
      uf_runtime_init --probe || return 1
      case "${positional[0]:-state}" in
        state)
          uf_pkg_state_report
          return $?
          ;;
        *)
          uf_error "Unknown package subcommand: ${positional[0]:-}"
          return 2
          ;;
      esac
      ;;
    *)
      uf_error "Unknown command: ${command}"
      uf_info "Run '${UF_NAME} help' for usage."
      return 2
      ;;
  esac
}
