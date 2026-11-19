# Ubuntuify Fedora

Transform a standard Fedora Workstation GNOME installation into an Ubuntu-like
desktop experience while keeping Fedora underneath. Ubuntuify Fedora is an
independent community project inspired by the Ubuntu GNOME desktop. It configures
appearance, fonts, the dock, desktop icons, the system tray, keyboard shortcuts,
window behaviour, workspaces, notifications, power behaviour, favorites,
Nautilus, sound, the wallpaper and, only when explicitly requested, Plymouth
and GDM branding.

It does **not** replace Fedora repositories, `/etc/os-release`, DNF, RPM, the
kernel, systemd or GNOME Shell. It does not install Debian packages or APT, does
not download scripts into a shell, and does not redistribute Ubuntu or Yaru
artwork.

> Not affiliated with Canonical, the Ubuntu project or the Fedora Project.
> Ubuntu and Yaru are trademarks of their respective owners.

## Table of contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Profiles](#profiles)
- [Components](#components)
- [Configuration](#configuration)
- [Backups and rollback](#backups-and-rollback)
- [Interactive mode](#interactive-mode)
- [Idempotency and safety](#idempotency-and-safety)
- [Diagnostics](#diagnostics)
- [Troubleshooting](#troubleshooting)
- [Compatibility](#compatibility)
- [Known limitations](#known-limitations)
- [Accessibility and internationalization](#accessibility-and-internationalization)
- [Logging](#logging)
- [Security](#security)
- [Versioning](#versioning)
- [Development](#development)
- [Testing](#testing)
- [Project layout](#project-layout)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Yaru appearance** — GTK, GNOME Shell and icon themes from Fedora packages,
  with graceful fallbacks when a theme is not packaged for the release.
- **Ubuntu typography** — Ubuntu / Ubuntu Mono when available; otherwise the
  current fonts are kept and a warning is shown.
- **Ubuntu dock** — left-positioned Dash to Dock, 48 px icons, Ubuntu-like
  click, scroll, trash, mount and applications-button behaviour.
- **Desktop icons** — Desktop Icons NG (DING) with Home, Trash, volume and
  network-volume icons.
- **System tray** — AppIndicator / KStatusNotifierItem support.
- **Ubuntu shortcuts** — terminal, Home, Show Applications, lock screen, tiling
  and workspace shortcuts, with conflict detection.
- **Tiling and window behaviour** — Tiling Assistant plus Ubuntu-like window
  buttons, focus mode, edge tiling and workspaces.
- **Top panel** — date, weekday, battery percentage, clock format.
- **Notifications and power** — lock-screen notifications and Ubuntu-like power
  button behaviour at the GNOME level.
- **Favorites and defaults** — Ubuntu-like application favorites and sensible
  default applications, without removing the user's existing favorites.
- **Original wallpaper** — generated locally at install time from the Yaru
  palette; no Ubuntu wallpaper is copied.
- **Sound** — Yaru sound theme where supported.
- **Opt-in boot branding** — Plymouth and GDM changes are separate components
  that require an explicit flag, root privileges and confirmation.
- **Reversible by design** — timestamped, never-overwritten backups plus a
  per-setting transaction log allow full or component-level restore.
- **Safe automation** — `--dry-run`, `--yes`, idempotent operations, schema and
  key checks, optional-setting fallbacks and extension compatibility checks.
- **Diagnostics** — `status`, `status --components`, `status --score` and
  `doctor` explain what is configured and what is missing.

## Screenshots

Screenshots are intentionally not shipped in the source tree. Capture them on a
Fedora GNOME VM after `ubuntuify install` and place them in `docs/images/`.

```text
docs/images/desktop-light.png    Ubuntu-like desktop, light appearance
docs/images/desktop-dark.png     Ubuntu-like desktop, dark appearance
docs/images/dock.png             Left dock, 48 px icons, applications button
docs/images/doctor.png           ubuntuify doctor output
```

Suggested README image block (uncomment after adding the files):

```markdown
![Ubuntu-like Fedora desktop](docs/images/desktop-dark.png)
```

## Requirements

- Fedora Workstation 44 or newer (Fedora 45 is the development environment).
- GNOME Shell 45 or newer, preferably on Wayland.
- A normal user session with a working session D-Bus (GSettings/dconf).
- `python3`, `gsettings` (glib2), `dconf`, `dnf`, `rpm`.
- `sudo` for package installation and opt-in boot components.
- Optional: `gnome-extensions`, `curl`, `fc-list`.

Ubuntuify detects the running GNOME version and extension UUIDs at runtime. It
does not hard-code extension versions, so it is designed to keep working across
future Fedora/GNOME releases. Components that are genuinely unavailable are
skipped with a warning rather than forced.

## Installation

```bash
git clone <repository> ubuntuify-fedora
cd ubuntuify-fedora
./ubuntuify doctor
./ubuntuify install --dry-run
./ubuntuify install
```

The launcher is a normal executable. There is no build step, no `pip install`,
no installer and no external TUI framework. Python 3 is required for state,
JSON, GVariant, extension and artwork helpers and is already present on Fedora
Workstation.

To use the command from any directory:

```bash
mkdir -p ~/.local/bin
ln -sf "$PWD/ubuntuify" ~/.local/bin/ubuntuify
# ~/.local/bin must be on PATH
```

After installing, log out and back in (or reboot). GNOME Shell loads themes and
extensions at login; Wayland does not support Alt+F2 `r`.

### Recommended first run

```bash
./ubuntuify install
```

The interactive run:

1. detects Fedora, GNOME, session and tools;
2. creates a timestamped backup (unless `--no-backup` is used);
3. installs only the Fedora packages it needs;
4. applies the default `full` profile;
5. reports configured, skipped and failed components;
6. prints the log path and next commands.

If a package or extension is unavailable, the affected component is skipped or
reported as a warning. The rest of the desktop is still configured.

### Non-interactive installation

```bash
./ubuntuify install --yes
```

`--yes` accepts normal prompts but deliberately **never** downloads an
extension from extensions.gnome.org. If Desktop Icons NG or another extension is
not packaged by Fedora, it is skipped. Use `--online-extensions` explicitly if
you want the fallback:

```bash
./ubuntuify install --online-extensions
```

Other useful forms:

```bash
./ubuntuify install --profile minimal
./ubuntuify install --profile dark
./ubuntuify install --component dock
./ubuntuify install --dry-run
./ubuntuify install --no-backup
./ubuntuify install --backup-now
```

### Configuration before installing

Copy the sample and edit only the keys you need:

```bash
mkdir -p ~/.config/ubuntuify
./ubuntuify config --sample > ~/.config/ubuntuify/config.conf
${EDITOR:-vi} ~/.config/ubuntuify/config.conf
./ubuntuify config          # show effective values
./ubuntuify install
```

User configuration overrides shipped defaults; command-line flags override the
user configuration. Unknown keys are ignored. Invalid values are rejected or
replaced by the documented default and are never written blindly. The file is
parsed as `key=value`; it is never sourced and cannot execute commands.

### Optional boot branding

Plymouth and GDM are not part of any profile and are never enabled implicitly.
They require root, an interactive terminal and explicit confirmation:

```bash
sudo -v
./ubuntuify install --component plymouth
./ubuntuify install --component gdm
```

Both components create a backup first. Roll them back with:

```bash
./ubuntuify restore --component plymouth
./ubuntuify restore --component gdm
```

Test boot branding in a disposable VM with a snapshot. A broken Plymouth or GDM
configuration can prevent the graphical session from starting.

## Usage

```text
ubuntuify                         Interactive menu
ubuntuify install                 Apply the configured profile
ubuntuify install --dry-run       Show every planned change
ubuntuify install --profile dark  Use the dark Yaru appearance
ubuntuify install --component dock
ubuntuify status                  Current profile and settings
ubuntuify status --components     Per-component state
ubuntuify status --score          UX completeness score
ubuntuify doctor                  Diagnose system and installation
ubuntuify backup                  Create a backup now
ubuntuify restore                 Restore the most recent backup
ubuntuify restore --backup ID     Restore a specific backup
ubuntuify restore --component theme
ubuntuify update                  Re-apply after a Fedora/GNOME update
ubuntuify profile light|dark      Switch appearance only
ubuntuify reset                   Reset Ubuntuify-managed settings
ubuntuify defaults                Configure default applications
ubuntuify uninstall               Restore state and remove Ubuntuify data
ubuntuify config                  Show effective configuration
ubuntuify config --sample         Print a configuration template
ubuntuify package state           Show packages installed by Ubuntuify
ubuntuify components              List components
ubuntuify version
ubuntuify help [command]
```

### Global options

```text
--dry-run              Show and log changes without applying them
--yes                  Non-interactive; accept normal prompts; never uses EGO fallback
--verbose              Increase diagnostic output
--quiet                Reduce output
--no-color             Disable color
--no-backup            Skip the automatic pre-install backup
--backup-now           Force a fresh backup before installing
--remove-packages      Remove packages installed by Ubuntuify on uninstall
--profile NAME         Select a profile
--component NAME       Apply or restore one component
--backup ID            Restore a specific backup
--online-extensions    Allow the extensions.gnome.org fallback
--no-online-extensions Never download extensions
```

### Command-specific notes

- `install` applies the configured or selected profile, or an explicit component.
- `update` re-applies the recorded profile and reports Fedora/GNOME version
  changes. It does not add boot components or enable the online extension
  fallback.
- `profile light|dark` switches appearance only. Use `install --profile dark`
  for a full dark desktop.
- `reset` compares current values with applied values and preserves user edits
  made after installation.
- `defaults` configures MIME defaults and Nautilus preferences.
- `package state` reports packages recorded as installed by Ubuntuify.
- `help [command]` and `--help` work for every command.

## Profiles

| Profile | Purpose |
| --- | --- |
| `full` | Complete Ubuntu-like desktop (default). |
| `minimal` | Visual core: Yaru theme, icons, cursor, fonts and wallpaper. |
| `dark` | Full desktop using the dark Yaru variants. |
| `classic` | Full desktop without Tiling Assistant and notification/power tweaks. |
| `custom` | Only the components listed in `custom.components`. |

Profiles never include Plymouth or GDM. Those are explicit components:

```bash
./ubuntuify install --component plymouth
./ubuntuify install --component gdm
```

Custom profiles are configured in `~/.config/ubuntuify/config.conf`:

```ini
profile=custom
custom.components=theme;icons;cursor;fonts;dock;wallpaper
```

Explicit `--component` installs on a system without prior state set the profile
to `custom` and record the requested components.

## Components

Apply order is fixed so extensions exist before their settings are written:

```text
appearance, theme, icons, cursor, fonts, overview, panel, dock, desktop-icons,
tray, tiling, shortcuts, windows, workspaces, notifications, power, nautilus,
favorites, wallpaper, sound, default-apps, plymouth, gdm
```

| Component | Title | Notes |
| --- | --- | --- |
| `appearance` | Appearance | Accent, hot corner, 24-hour clock. |
| `theme` | Yaru theme | GTK, icon and GNOME Shell theme, with fallback. |
| `icons` | Yaru icons | Yaru icon theme. |
| `cursor` | Cursor theme | Yaru cursor, size 24 by default. |
| `fonts` | Ubuntu fonts | Ubuntu / Ubuntu Mono with fallback. |
| `overview` | Overview and hot corner | GNOME overview behaviour. |
| `panel` | Top panel | Date, weekday, seconds, battery percentage. |
| `dock` | Ubuntu dock | Dash to Dock, left, 48 px icons. |
| `desktop-icons` | Desktop icons | DING Home, Trash, volumes. |
| `tray` | System tray | AppIndicator/KStatusNotifierItem. |
| `tiling` | Tiling Assistant | Edge tiling helper. |
| `shortcuts` | Keyboard shortcuts | Terminal, Home, Show Apps, lock, tiling. |
| `windows` | Window behaviour | Buttons, focus, raise, edge tiling. |
| `workspaces` | Workspaces | Dynamic workspaces. |
| `notifications` | Notifications | Lock-screen notifications. |
| `power` | Power behaviour | GNOME-level power button. |
| `nautilus` | GNOME Files | Nautilus preferences. |
| `favorites` | Application favorites | Ubuntu-like favorites, merge by default. |
| `wallpaper` | Wallpaper | Locally generated Ubuntu-inspired wallpaper. |
| `sound` | Sound theme | Yaru sound theme. |
| `default-apps` | Default applications | MIME defaults. |
| `plymouth` | Plymouth boot branding | Optional, root, explicit confirmation. |
| `gdm` | GDM login background | Optional, root, explicit confirmation. |

Aliases:

```text
defaults -> default-apps
ding, desktopicons, desktop-icon -> desktop-icons
appindicator, app-indicator -> tray
gnome-behavior, behaviour -> windows
shell-theme, shell -> theme
font -> fonts
icon -> icons
shortcut, keyboard -> shortcuts
```

Use `./ubuntuify components` for aliases and descriptions, and
`./ubuntuify install --component <name>` to apply a single component.

## Configuration

The default configuration lives in `config/ubuntu-defaults.conf`. User
configuration is `~/.config/ubuntuify/config.conf`. Command-line options
override the user configuration, which overrides shipped defaults.

Example:

```ini
# ~/.config/ubuntuify/config.conf
profile=full
color_scheme=dark

dock.icon_size=48
dock.autohide=false
dock.show_trash=true

desktop_icons.enabled=true
panel.show_seconds=false

wallpaper.mode=ubuntu-default
wallpaper.width=2560
wallpaper.height=1440

shortcuts.on_conflict=ask
online_extensions=ask
backup.keep=10
```

### Configuration reference

| Key | Default | Meaning |
| --- | --- | --- |
| `profile` | `full` | Installed profile. |
| `color_scheme` | `default` | `default`, `light` or `dark`. |
| `theme.install` | `true` | Install Yaru GTK/Shell theme. |
| `theme.name` | `Yaru` | Light GTK theme. |
| `theme.dark_name` | `Yaru-dark` | Dark GTK theme. |
| `theme.shell_name` | `Yaru` | Light GNOME Shell theme. |
| `theme.shell_dark_name` | `Yaru-dark` | Dark GNOME Shell theme. |
| `icons.install` | `true` | Install Yaru icons. |
| `icons.name` | `Yaru` | Light icon theme. |
| `icons.dark_name` | `Yaru-dark` | Dark icon theme. |
| `cursor.install` | `true` | Install Yaru cursor. |
| `cursor.name` | `Yaru` | Cursor theme. |
| `cursor.size` | `24` | Cursor size. |
| `fonts.install` | `true` | Install Ubuntu fonts. |
| `fonts.family` | `Ubuntu` | UI font. |
| `fonts.monospace_family` | `Ubuntu Mono` | Monospace font. |
| `fonts.size` | `11` | UI font size. |
| `fonts.monospace_size` | `13` | Monospace font size. |
| `fonts.titlebar_size` | `11` | Titlebar font size. |
| `appearance.accent` | `orange` | Accent color. |
| `appearance.hot_corner` | `true` | Hot corner. |
| `appearance.clock_24h` | `false` | 24-hour clock. |
| `dock.enabled` | `true` | Enable dock configuration. |
| `dock.position` | `left` | Dock position. |
| `dock.icon_size` | `48` | Dock icon size. |
| `dock.extend_height` | `true` | Extend dock height. |
| `dock.fixed` | `true` | Fixed dock. |
| `dock.autohide` | `false` | Auto-hide. |
| `dock.intellihide` | `false` | Intelligent hide. |
| `dock.show_favorites` | `true` | Show favorites. |
| `dock.show_running` | `true` | Show running apps. |
| `dock.show_trash` | `true` | Show trash. |
| `dock.show_mounts` | `true` | Show mounts. |
| `dock.show_apps_button` | `true` | Show applications button. |
| `dock.apps_button_at_top` | `true` | Applications button at top. |
| `dock.click_action` | `minimize-or-previews` | Click action. |
| `dock.scroll_action` | `cycle-windows` | Scroll action. |
| `dock.multi_monitor` | `false` | Multi-monitor dock. |
| `dock.opacity` | `0.8` | Dock opacity. |
| `dock.theme_shrink` | `true` | Shrink icons to fit. |
| `desktop_icons.enabled` | `true` | Enable desktop icons. |
| `desktop_icons.home` | `true` | Home icon. |
| `desktop_icons.trash` | `true` | Trash icon. |
| `desktop_icons.volumes` | `true` | Volume icons. |
| `desktop_icons.network_volumes` | `true` | Network volume icons. |
| `desktop_icons.icon_size` | `standard` | Icon size. |
| `desktop_icons.start_corner` | `top-left` | Start corner. |
| `desktop_icons.show_drop_placeholder` | `true` | Drop placeholder. |
| `tray.enabled` | `true` | Enable AppIndicator. |
| `tray.icon_size` | `16` | Tray icon size. |
| `tray.icon_padding` | `0` | Tray icon padding. |
| `tiling.enabled` | `true` | Enable tiling. |
| `panel.show_date` | `true` | Show date. |
| `panel.show_weekday` | `true` | Show weekday. |
| `panel.show_seconds` | `false` | Show seconds. |
| `panel.show_battery_percentage` | `true` | Show battery percentage. |
| `panel.clock_format` | empty | Custom clock format. |
| `windows.buttons` | `appmenu:minimize,maximize,close` | Window buttons. |
| `windows.animations` | `true` | Animations. |
| `windows.focus_mode` | `click` | Focus mode. |
| `windows.raise_on_click` | `true` | Raise on click. |
| `windows.auto_raise` | `false` | Auto-raise. |
| `windows.edge_tiling` | `true` | Edge tiling. |
| `workspaces.dynamic` | `true` | Dynamic workspaces. |
| `workspaces.only_primary` | `true` | Workspaces on primary display. |
| `notifications.show_in_lock_screen` | `true` | Lock-screen notifications. |
| `power.button_action` | `interactive` | Power button action. |
| `ubuntu_shortcuts` | `true` | Ubuntu shortcuts. |
| `shortcuts.on_conflict` | `ask` | `ask`, `keep` or `replace`. |
| `shortcuts.terminal` | `true` | Terminal shortcut. |
| `shortcuts.home` | `true` | Home shortcut. |
| `shortcuts.show_apps` | `true` | Show Applications shortcut. |
| `shortcuts.lock` | `true` | Lock shortcut. |
| `shortcuts.tiling` | `true` | Tiling shortcuts. |
| `nautilus.enabled` | `true` | Nautilus configuration. |
| `favorites.enabled` | `true` | Favorites configuration. |
| `favorites.merge` | `true` | Merge rather than replace. |
| `favorites.list` | Ubuntu-like list | Semicolon-separated desktop files. |
| `defaults.enabled` | `true` | Default applications. |
| `wallpaper.mode` | `ask` | `ask`, `ubuntu-default`, `keep` or path. |
| `wallpaper.path` | commented | Absolute PNG path. |
| `wallpaper.width` | `2560` | Generated wallpaper width. |
| `wallpaper.height` | `1440` | Generated wallpaper height. |
| `sound.enabled` | `true` | Sound theme. |
| `sound.theme` | `Yaru` | Sound theme. |
| `plymouth` | `false` | Opt-in boot branding. |
| `gdm` | `false` | Opt-in login background. |
| `online_extensions` | `ask` | `ask`, `yes` or `no`. |
| `backup.keep` | `10` | Backups to retain. |

Unknown keys are ignored. Invalid values are rejected or replaced by the
documented default. Booleans accept `true/false/1/0/yes/no/on/off`.

## Backups and rollback

Ubuntuify creates a timestamped backup under
`~/.local/share/ubuntuify/backups/` before the first install of a profile and
again when the profile changes. Backups are never overwritten. Each setting
Ubuntuify changes is also recorded in `original-settings.tsv`, which enables
component-level rollback.

```bash
./ubuntuify backup                     # manual snapshot
./ubuntuify restore                    # restore the newest backup
./ubuntuify restore --backup ID        # restore a specific backup
./ubuntuify restore --component theme  # restore one component
./ubuntuify reset                      # forget managed changes, keep user edits
./ubuntuify uninstall                  # restore + remove Ubuntuify data
```

A backup contains:

```text
meta.txt
dconf.dump
gsettings.dump
extensions-installed.txt
extensions-enabled.txt
extensions-disabled.txt
favorites.txt
packages-before.txt
state.json
original-settings.tsv
applied-settings.tsv
user-config.tar
checksums.sha256
```

`restore` verifies that the backup exists, has metadata, contains at least one
restorable settings source and passes its checksum manifest before changing
anything.

Full restore:

1. asks for confirmation (unless `--yes` or dry-run);
2. loads the saved dconf dump;
3. falls back to recorded original settings if dconf is unavailable;
4. restores archived user configuration files;
5. restores recorded state;
6. clears transaction logs.

Packages are **not** removed by `restore`. Use `uninstall --remove-packages`
for cleanup.

Component restore reads `original-settings.tsv` and restores only entries whose
component matches. It does not load the dconf dump, so unrelated settings are
untouched. Original values are recorded only once, at the first change.

`reset` compares the current value with the applied value:

- if they match, the original is restored;
- if the user changed it afterwards, the user's value is preserved and the
  setting is reported as skipped.

`uninstall`:

1. disables extensions Ubuntuify enabled;
2. restores Plymouth/GDM if those components are present;
3. restores every recorded original setting;
4. optionally removes packages recorded as installed by Ubuntuify;
5. removes generated wallpapers, cache and state;
6. keeps backups and logs under `~/.local/share/ubuntuify/`.

If state is missing but backups exist, uninstall tells you to use
`restore --backup <id>` instead of guessing.

See [docs/rollback.md](docs/rollback.md) for full details.

## Interactive mode

Running `ubuntuify` with no arguments launches a plain-text menu:

```text
╔══════════════════════════════════════════════╗
║              UBUNTUIFY FEDORA                ║
║                                              ║
║       Ubuntu GNOME Experience for Fedora     ║
╚══════════════════════════════════════════════╝

System:
  Fedora 44
  GNOME 50
  Wayland
  x86_64
```

No external TUI framework is required. The menu can install components, run
diagnostics, create and restore backups, and uninstall.

## Idempotency and safety

Running `ubuntuify install` multiple times must not:

- duplicate configuration;
- duplicate packages;
- corrupt dconf;
- duplicate favorites;
- duplicate extensions;
- create multiple backups unnecessarily;
- break GNOME.

The installer detects current state. Example output:

```text
✓ Yaru already installed
✓ AppIndicator already installed
✓ DING already installed
→ Updating dock configuration
→ No changes required for fonts
```

Safety properties:

- Runs as the normal user; only individual DNF, Plymouth and GDM commands use
  `sudo`.
- `set -Eeuo pipefail` is used.
- All shell expansions are quoted; `eval` is not used.
- Configuration is parsed, never sourced.
- `/etc/os-release` is parsed line by line.
- Backup IDs are validated before path use.
- Recursive removal is restricted to the Ubuntuify state root.
- Extension UUIDs and archives are validated before installation.
- JSON state is written atomically with mode `0600`.
- `--dry-run` creates no state, backups, packages, dconf writes or extension
  downloads.
- `--yes` skips the online extension fallback.
- Unknown or missing settings are skipped, not forced.
- Existing shortcut conflicts are kept by default.
- `reset` preserves settings the user changed after install.
- Uninstall keeps packages unless `--remove-packages` is explicit.
- Backups are verified before a full restore.

## Diagnostics

```bash
./ubuntuify status
./ubuntuify status --components
./ubuntuify status --score
./ubuntuify doctor
```

`status` reports profile, theme, dock, icons, tray, tiling, shortcuts and other
state. `status --components` reports per-component state. `status --score`
reports UX completeness. `doctor` checks Fedora, GNOME, session, tools, packages,
extensions, themes, fonts, GSettings, backup and state. It exits non-zero when
it finds critical errors.

## Troubleshooting

Start with:

```bash
./ubuntuify doctor
./ubuntuify status --components
tail -n 100 ~/.local/share/ubuntuify/logs/*.log
```

Common causes:

- A missing GSettings schema or key on an older or newer GNOME release. Expect
  `[SKIP]` and a clear `doctor` line; the rest of the install continues.
- An extension not enabled yet. Log out and back in.
- A change that only appears after logout/login. Wayland does not support
  Alt+F2 `r`.
- Known Fedora packaging gaps: Ubuntu fonts, Yaru cursor and Desktop Icons NG
  may be absent. These are warnings, not critical errors.
- Boot branding tested in a VM with a snapshot. A broken Plymouth/GDM
  configuration can prevent the graphical session from starting.

See [docs/troubleshooting.md](docs/troubleshooting.md).

## Compatibility

- **Target:** Fedora Workstation 44+ with GNOME Shell 45+ (including GNOME 50+).
- **Session:** Wayland is the primary target; X11 generally works for
  GSettings-based components.
- **Extensions:** Fedora RPMs are preferred. The official extensions.gnome.org
  fallback is opt-in and requires confirmation; it is never used by `--yes`.
- **Known Fedora packaging gaps:** Ubuntu fonts, the Yaru cursor theme and
  Desktop Icons NG may be unavailable on a given Fedora release. Ubuntuify
  detects this and skips the component with a warning.
- **Fidelity:** Ubuntu's GNOME is downstream-patched and ships some components
  differently. Ubuntuify aims for maximum practical fidelity, not a byte-for-byte
  copy of Ubuntu.
- **GNOME version handling:** schemas and keys are checked at runtime. Future
  GNOME releases may skip some settings until Ubuntuify is updated.

## Known limitations

- Ubuntu fonts, the Yaru cursor theme and Desktop Icons NG may not be packaged
  by Fedora; those components skip with a warning.
- Ubuntu's downstream GNOME patches, Snap integration, APT and Ubuntu system
  services are not reproduced.
- Plymouth/GDM require an interactive terminal and are not covered by profiles.
- GDM cannot be fully themed on Fedora without patching GDM; only the greeter
  background is supported.
- The automated suite cannot prove that GNOME Shell renders a theme; VM testing
  is required.
- Backups contain dconf dumps and user configuration; they are stored with
  user permissions under `~/.local/share/ubuntuify` but are not encrypted.
- A compromised user account can modify Ubuntuify state and configuration, as
  it can modify any other user-level desktop setting.

## Accessibility and internationalization

Ubuntuify does not make the project unusable for screen readers, keyboard-only
users, high-contrast users or reduced-motion users. It respects GNOME
accessibility preferences and does not force animations if reduced motion is
enabled.

It avoids hard-coding assumptions about language, keyboard or locale. It does
not assume English, a US keyboard, a US locale or a specific desktop background,
and it never replaces the user's locale.

## Logging

Every operation is logged under `~/.local/share/ubuntuify/logs/`. Example:

```text
2026-11-19 17:00:01 INFO Starting Ubuntuify
2026-11-19 17:00:02 INFO Fedora 44 detected
2026-11-19 17:00:02 INFO GNOME 50 detected
2026-11-19 17:00:03 INFO Creating backup
2026-11-19 17:00:08 INFO Installing Yaru
2026-11-19 17:00:14 INFO Enabling AppIndicator
2026-11-19 17:00:15 INFO Configuring Dash to Dock
```

Terminal output uses `[INFO]`, `[OK]`, `[WARN]`, `[ERROR]` and `[SKIP]`.

## Security

Ubuntuify runs as your normal user and escalates only individual DNF, Plymouth
and GDM commands with `sudo`. It does not store passwords, collect telemetry,
pipe downloads into a shell or execute downloaded scripts. Extension fallback
downloads use HTTPS and are UUID- and archive-validated before installation.

See [SECURITY.md](SECURITY.md).

## Versioning

Semantic versioning: `MAJOR.MINOR.PATCH`. Current release: `1.0.0`.

## Development

There is no build step:

```bash
git clone <repository> ubuntuify-fedora
cd ubuntuify-fedora
bash tests/run.sh
```

Useful checks:

```bash
bash -n ubuntuify bin/ubuntuify
for file in src/*.sh src/*/*.sh tests/*.sh tests/*/*.sh; do
  bash -n "$file" || exit 1
done
python3 -m py_compile src/core/state.py src/core/gvariant.py \
  src/core/artwork.py src/extensions/ego_helper.py
```

If available, run `shellcheck` on changed Bash files. Fix real warnings instead
of adding blanket suppressions.

Style:

- `#!/usr/bin/env bash` and `set -Eeuo pipefail` in launchers and tests.
- `snake_case` functions prefixed `uf_`; globals `UF_UPPER`.
- Quote all expansions, including array expansions.
- Use `command -v`/`uf_have` before invoking optional tools.
- Diagnostics go to stderr through `uf_info`/`uf_warn`/etc.
- Never add `eval`, `curl | bash`, or unquoted `rm -rf`.
- Use `uf_setting`/`uf_gs_set` rather than raw `gsettings set`.
- Check optional settings and return `2` for skipped/unavailable where expected.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Testing

```bash
bash tests/run.sh
```

Each `tests/unit/*.sh` and `tests/integration/*.sh` file runs in its own Bash
process. The harness:

- creates a temporary `HOME` and XDG directories before sourcing `src/lib.sh`;
- puts `tests/mocks` first on `PATH`;
- seeds a realistic Fedora GNOME baseline;
- removes the sandbox on exit, including after a failing test.

Tests use `uf_test`, `uf_assert_eq`, `uf_assert_contains`,
`uf_assert_no_file` and `uf_assert_fails`. There is no Bats, shellcheck or
network dependency.

Run one file while developing:

```bash
bash tests/unit/test_gsettings.sh
bash tests/integration/test_cli.sh
```

### Coverage

| File | Focus |
| --- | --- |
| `test_utils.sh` | List splitting, dedupe, integer/bool validation, path guard. |
| `test_config.sh` | Precedence, quoting, validation, persistence, sample output. |
| `test_gsettings.sh` | Missing schema/key skip, idempotency, original/applied log, enum/range validation, dry-run, restore/reset. |
| `test_gvariant.sh` | GVariant list get/add/remove/has. |
| `test_state.sh` | Atomic JSON init/get/set/list/component status, backups preserved. |
| `test_detection.sh` | os-release, GNOME version, session, Fedora refusal. |
| `test_components.sh` | Registry, aliases, profile expansion, order. |
| `test_backup.sh` | Timestamped unique IDs, create/verify/prune, path guard. |
| `test_engine.sh` | Profile resolution, dry-run safety, backup reuse, unknown components. |
| `test_cli.sh` | Version/help, unknown command/option, status, score, config sample, dry-run, bad profile, doctor. |

The tests intentionally allow `[SKIP]`, `[WARN]` and `[ERROR]` output for
negative cases; the exit status and assertions decide pass/fail.

### Dry-run first

Every mutation path has a dry-run:

```bash
./ubuntuify install --profile full --dry-run
./ubuntuify restore --dry-run
./ubuntuify uninstall --dry-run
```

Dry-run must not create state, backups, packages, dconf writes or extension
downloads.

### Disposable Fedora VM workflow

Use a Fedora Workstation VM with GNOME and Wayland. Do not test destructive
rollback on your daily machine.

```text
1. Install Fedora Workstation 44+ in a VM (GNOME, Wayland).
2. Snapshot the clean VM.
3. Clone the repository in the VM.
4. Run doctor, dry-run and install.
5. Log out and back in (or reboot).
6. Verify status, components, doctor and the desktop manually.
7. Test a profile switch.
8. Test rollback and uninstall.
9. Restore the clean VM snapshot if needed.
```

For opt-in boot components, test in a separate snapshot because a broken
Plymouth/GDM configuration can make the VM unbootable.

## Project layout

```text
ubuntuify-fedora/
├── ubuntuify                 # repository launcher
├── bin/ubuntuify             # PATH-friendly launcher
├── config/
│   ├── ubuntu-defaults.conf  # shipped defaults
│   └── extensions.conf       # extension UUID/package/EGO registry
├── src/
│   ├── lib.sh                # globals, XDG paths, module loading
│   ├── main.sh               # entry point and error traps
│   ├── cli.sh                # argument parsing, help, interactive menu
│   ├── engine.sh             # install/restore/update/uninstall workflows
│   ├── components.sh         # component registry and dispatch
│   ├── config.sh             # layered configuration
│   ├── core/                 # detection, logging, state, GSettings, sudo
│   ├── packages/             # DNF/RPM integration
│   ├── backup/               # snapshots and restore
│   ├── extensions/           # RPM/EGO extension management, tiling
│   ├── theme/                # Yaru, icons, cursor, fonts
│   ├── gnome/                # panel, shortcuts, windows, workspaces, ...
│   ├── desktop/              # dock, icons, tray, wallpaper, sound
│   ├── applications/         # favorites, Nautilus, default apps
│   ├── boot/                 # opt-in Plymouth and GDM
│   └── diagnostics/          # doctor and status
├── tests/
│   ├── run.sh
│   ├── unit/
│   ├── integration/
│   ├── mocks/
│   ├── fixtures/
│   └── lib/harness.sh
├── docs/
│   ├── architecture.md
│   ├── extensions.md
│   ├── rollback.md
│   ├── troubleshooting.md
│   └── testing.md
├── README.md
├── INSTALL.md
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
├── LICENSE
└── prompt.md
```

## Contributing

Bug reports, Fedora release testing and component fixes are welcome. Read
[CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Please do not
add copied Ubuntu/Yaru artwork or third-party binaries.

## License

MIT — see [LICENSE](LICENSE).