# Changelog

All notable changes to Ubuntuify Fedora are documented here. The project uses
[Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-19

Initial release.

### Added

- Fedora/GNOME/session detection with Fedora-only guard.
- CLI commands: `install`, `uninstall`, `restore`, `update`, `status`,
  `doctor`, `backup`, `profile`, `reset`, `defaults`, `components`, `config`,
  `package`, `version`, `help`.
- Interactive menu when no command is supplied.
- Profiles: `full`, `minimal`, `dark`, `classic`, `custom`.
- Yaru GTK/Shell themes, icons, cursor and Ubuntu font integration with
  graceful Fedora packaging fallbacks.
- Dash to Dock configuration: left position, 48 px icons, Ubuntu-like click,
  scroll, trash, mount and applications-button behavior.
- Desktop Icons NG (DING) integration for Home, Trash and volume icons.
- AppIndicator/KStatusNotifierItem tray support.
- Tiling Assistant, Ubuntu shortcuts with conflict detection, window buttons,
  focus mode, workspaces, notifications and power behavior.
- Ubuntu-like favorites, Nautilus preferences and default applications.
- Locally generated Ubuntu-inspired wallpapers (no Ubuntu assets copied).
- Yaru sound theme with fallback.
- Opt-in Plymouth and GDM boot branding with explicit confirmation, backups
  and component restore.
- Timestamped, never-overwritten backups with checksum verification.
- Per-setting transaction logs for full and component-level rollback.
- `reset` that preserves user edits made after install.
- RPM-first extension management with version compatibility checks, conflict
  detection and an opt-in, validated extensions.gnome.org fallback.
- JSON state, GVariant and metadata helpers using only the Python standard
  library.
- Unit and integration test suite with an isolated HOME and mocked system
  tools.
- Documentation: README, install, architecture, extensions, rollback,
  troubleshooting, testing, security and contribution guides.

### Security

- Normal-user execution with per-command `sudo`.
- No `curl | bash`, no downloaded script execution, no telemetry.
- HTTPS-only extension fallback with UUID/archive validation.
- Guarded recursive removal confined to Ubuntuify state.

### Known limitations

- Ubuntu fonts, the Yaru cursor theme and Desktop Icons NG may not be packaged
  by Fedora; those components skip with a warning.
- Ubuntu's downstream GNOME patches, Snap integration, APT and Ubuntu system
  services are not reproduced.
- Plymouth/GDM require an interactive terminal and are not covered by profiles.
