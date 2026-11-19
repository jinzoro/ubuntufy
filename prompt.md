# Ubuntuify Fedora GNOME

## ROLE

You are a senior Linux desktop engineer, GNOME developer, Bash/Python developer, Fedora specialist, and open-source project maintainer.

Your task is to design and implement a **production-quality open-source project called `Ubuntuify Fedora`**.

The project must transform a standard **Fedora Workstation GNOME installation** into an extremely close reproduction of the **Ubuntu GNOME desktop experience**, while keeping Fedora underneath.

This is NOT intended to replace Fedora with Ubuntu.

The objective is:

> **Fedora Linux + Ubuntu GNOME desktop experience**

The project must be modular, reversible, version-aware, safe, well documented, and suitable for publishing on GitHub.

Do not create a toy script.

Do not produce a 100-line shell script that blindly changes settings.

Build this as a real project.

---

# 1. CORE OBJECTIVE

Create a tool that can transform Fedora GNOME into an Ubuntu-like desktop environment covering as many aspects of the Ubuntu desktop experience as technically possible.

The transformation should cover:

- Ubuntu/Yaru visual theme
- GTK theme
- GNOME Shell theme
- icon theme
- cursor theme
- fonts
- wallpaper
- Ubuntu-style top panel
- Ubuntu-style dock
- application launcher
- desktop icons
- system tray / AppIndicators
- mounted drives on desktop
- Trash on desktop
- Ubuntu-like application favorites
- Ubuntu-like keyboard shortcuts
- window behavior
- tiling
- workspace behavior
- animations
- Nautilus behavior
- notifications
- lock screen
- login experience where safely possible
- Plymouth/boot branding where safely possible
- default applications
- sound theme
- GNOME settings
- extension configuration
- appearance settings
- power behavior
- touchpad/mouse behavior
- accessibility-related desktop defaults where appropriate

The project should attempt to reproduce **Ubuntu's behavior**, not merely its colors.

---

# 2. IMPORTANT PHILOSOPHY

Do NOT attempt to convert Fedora internally into Ubuntu.

Never:

- replace Fedora repositories
- modify `/etc/os-release`
- fake Ubuntu identification
- replace Fedora's package manager
- replace Fedora's kernel
- replace Fedora's systemd
- remove Fedora desktop components unnecessarily
- install Ubuntu `.deb` packages on Fedora
- mix Ubuntu APT repositories with Fedora DNF repositories
- overwrite system files recklessly

The resulting system must remain a legitimate Fedora installation.

The project is a **desktop customization layer**.

Conceptually:

```text
                    Fedora Linux
                         │
                         ▼
                Fedora GNOME base
                         │
                         ▼
                  Ubuntuify layer
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
      Yaru           GNOME config      Extensions
        │                │                │
        └────────────────┼────────────────┘
                         ▼
              Ubuntu GNOME Experience
```

---

# 3. TARGET SYSTEM

Primary target:

```text
Fedora Workstation
GNOME
Wayland
```

The project must detect:

- Fedora version
- GNOME Shell version
- GNOME major version
- Wayland vs X11
- architecture
- desktop environment
- installed extensions
- installed themes
- available repositories
- available packages

Initially prioritize Fedora 44+ and GNOME 50+, but design the project so future Fedora/GNOME versions can be supported.

Do NOT hard-code GNOME extension versions.

---

# 4. PROJECT NAME

Use:

```text
ubuntuify-fedora
```

Executable:

```text
ubuntuify
```

Repository:

```text
ubuntuify-fedora
```

Suggested description:

> Transform Fedora GNOME into an Ubuntu-like desktop experience while keeping Fedora underneath.

---

# 5. PROJECT ARCHITECTURE

Do not create one giant script.

Use a modular architecture.

Suggested structure:

```text
ubuntuify-fedora/
│
├── README.md
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
├── INSTALL.md
│
├── ubuntuify
│
├── bin/
│   └── ubuntuify
│
├── src/
│   ├── core/
│   │   ├── detection.sh
│   │   ├── logging.sh
│   │   ├── errors.sh
│   │   ├── permissions.sh
│   │   └── state.sh
│   │
│   ├── backup/
│   │   ├── backup.sh
│   │   └── restore.sh
│   │
│   ├── packages/
│   │   ├── detect.sh
│   │   ├── install.sh
│   │   └── remove.sh
│   │
│   ├── theme/
│   │   ├── yaru.sh
│   │   ├── icons.sh
│   │   ├── fonts.sh
│   │   └── cursor.sh
│   │
│   ├── extensions/
│   │   ├── manager.sh
│   │   ├── appindicator.sh
│   │   ├── ding.sh
│   │   ├── dock.sh
│   │   └── tiling.sh
│   │
│   ├── gnome/
│   │   ├── appearance.sh
│   │   ├── panel.sh
│   │   ├── overview.sh
│   │   ├── shortcuts.sh
│   │   ├── windows.sh
│   │   ├── workspaces.sh
│   │   ├── notifications.sh
│   │   └── power.sh
│   │
│   ├── applications/
│   │   ├── nautilus.sh
│   │   ├── defaults.sh
│   │   └── favorites.sh
│   │
│   ├── desktop/
│   │   ├── dock.sh
│   │   ├── icons.sh
│   │   ├── wallpaper.sh
│   │   └── tray.sh
│   │
│   ├── boot/
│   │   ├── plymouth.sh
│   │   └── gdm.sh
│   │
│   └── diagnostics/
│       ├── doctor.sh
│       └── status.sh
│
├── config/
│   ├── ubuntu-defaults.conf
│   ├── dock.conf
│   ├── extensions.conf
│   ├── shortcuts.conf
│   └── appearance.conf
│
├── assets/
│   ├── wallpapers/
│   └── branding/
│
├── tests/
│   ├── unit/
│   ├── integration/
│   └── mocks/
│
└── docs/
    ├── architecture.md
    ├── extensions.md
    ├── rollback.md
    └── troubleshooting.md
```

You may improve this architecture if there is a better design.

---

# 6. LANGUAGE / IMPLEMENTATION

Use:

- Bash for low-level system operations
- Python where Bash becomes unnecessarily complex
- D-Bus/GSettings/dconf for GNOME configuration
- DNF for Fedora package management

Prefer simple, auditable code.

Avoid unnecessary dependencies.

If Python is used, use the Python standard library whenever possible.

Do not require a huge framework.

---

# 7. CLI

The main command must be:

```bash
ubuntuify
```

Provide commands:

```bash
ubuntuify install
ubuntuify uninstall
ubuntuify restore
ubuntuify update
ubuntuify status
ubuntuify doctor
ubuntuify backup
ubuntuify profile
ubuntuify reset
ubuntuify version
ubuntuify help
```

Examples:

```bash
ubuntuify install
```

Apply the full Ubuntu profile.

```bash
ubuntuify install --profile full
```

```bash
ubuntuify install --profile minimal
```

```bash
ubuntuify install --profile dark
```

```bash
ubuntuify install --component dock
```

```bash
ubuntuify install --component theme
```

```bash
ubuntuify install --component tray
```

```bash
ubuntuify restore
```

Restore the previous state.

```bash
ubuntuify doctor
```

Diagnose problems.

```bash
ubuntuify status
```

Show what is currently configured.

---

# 8. INTERACTIVE MODE

Running:

```bash
ubuntuify
```

without arguments should launch an interactive interface.

Example:

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

────────────────────────────────────────────────

1. Install Ubuntu Experience
2. Appearance
3. Dock
4. Desktop Icons
5. System Tray
6. GNOME Behavior
7. Shortcuts
8. Applications
9. Boot / Login
10. Diagnostics
11. Backup / Restore
12. Remove Ubuntuify
0. Exit
```

Use clean terminal UI.

Do not require external TUI frameworks unless necessary.

---

# 9. BACKUP SYSTEM

This is critical.

Before modifying anything, create a complete backup.

Backup:

- dconf database
- GSettings values
- enabled GNOME extensions
- disabled GNOME extensions
- GNOME favorites
- theme settings
- cursor settings
- font settings
- dock settings
- DING settings
- AppIndicator settings
- keyboard shortcuts
- wallpaper
- relevant user configuration files

Store state under:

```text
~/.local/share/ubuntuify/
```

For example:

```text
~/.local/share/ubuntuify/
├── backups/
│   └── 2026-11-19-170000/
├── state/
├── logs/
└── cache/
```

Never overwrite an existing backup.

Use timestamps.

Provide:

```bash
ubuntuify backup
```

and:

```bash
ubuntuify restore
```

Support restoring a specific backup:

```bash
ubuntuify restore --backup 2026-11-19-170000
```

---

# 10. IDEMPOTENCY

This is mandatory.

Running:

```bash
ubuntuify install
```

multiple times must NOT:

- duplicate configuration
- duplicate packages
- corrupt dconf
- duplicate favorites
- duplicate extensions
- create multiple backups unnecessarily
- break GNOME

The installer must detect the current state.

Example:

```text
✓ Yaru already installed
✓ AppIndicator already installed
✓ DING already installed
→ Updating dock configuration
→ No changes required for fonts
```

---

# 11. YARU THEME

Use the official Fedora-compatible Yaru packages/repositories whenever available.

Configure:

GTK:

```text
Yaru
```

Icons:

```text
Yaru
```

Cursor:

```text
Yaru
```

Dark mode:

```text
Yaru-dark
```

Support:

```bash
ubuntuify profile light
ubuntuify profile dark
```

Do not download random theme ZIP files from untrusted websites.

---

# 12. UBUNTU COLORS

Reproduce Ubuntu's visual language:

- Yaru purple/orange accents
- Ubuntu-style selection colors
- Ubuntu-like highlights
- consistent light/dark appearance

Do not randomly modify Fedora's system-wide color management.

---

# 13. UBUNTU FONTS

Detect whether Ubuntu fonts are available.

Install through Fedora-compatible packages when available.

Configure:

```text
Ubuntu
Ubuntu Mono
```

Do not break existing user fonts.

Provide fallback if Ubuntu fonts are unavailable.

---

# 14. UBUNTU DOCK

Implement Ubuntu-style dock behavior.

Target:

```text
Position:
LEFT

Icon size:
48px approximately

Favorites:
VISIBLE

Running indicators:
VISIBLE

Applications button:
VISIBLE

Trash:
VISIBLE

Mounted drives:
VISIBLE
```

Support:

- click behavior
- minimize behavior
- previews
- scrolling
- autohide
- intelligent hide
- opacity
- icon size
- monitor behavior

Do not blindly assume one Dash-to-Dock schema.

Detect the installed extension and inspect its actual available keys.

---

# 15. DESKTOP ICONS

Provide traditional desktop icons.

Use Desktop Icons NG where compatible.

Support:

```text
Home
Trash
Mounted volumes
Network volumes
Desktop files
Folders
Files
```

Configure:

- icon size
- grid spacing
- label behavior
- primary monitor
- desktop context menu

Target Ubuntu-like behavior.

---

# 16. SYSTEM TRAY

This is mandatory.

Install/configure AppIndicator support.

Support:

```text
Telegram
Discord
Steam
Dropbox
VPN clients
legacy tray applications
KStatusNotifierItem applications
```

The tool must detect whether AppIndicator is already installed.

Never install duplicate extensions.

---

# 17. TOP PANEL

Reproduce Ubuntu's GNOME top panel behavior as closely as possible.

Configure:

```text
Activities
Applications/menu behavior
Clock
Calendar
Notifications
Network
Bluetooth
Audio
Battery
System menu
```

Avoid destructive modifications to GNOME Shell.

Prefer supported extensions and GSettings.

---

# 18. CLOCK

Configure Ubuntu-like clock behavior:

- centered top clock where appropriate
- date visibility
- weekday behavior
- seconds disabled by default
- calendar integration

Provide configuration options.

---

# 19. WINDOW BUTTONS

Ubuntu historically uses:

```text
minimize
maximize
close
```

Configure window buttons appropriately.

Use:

```text
appmenu:minimize,maximize,close
```

where supported.

Do not break GNOME Shell if the schema changes.

---

# 20. GNOME WORKSPACES

Configure Ubuntu-like workspace behavior.

Target:

- dynamic workspaces
- keyboard navigation
- workspace switching
- overview behavior
- window placement

Provide:

```bash
ubuntuify install --component workspaces
```

---

# 21. TILING

Install/configure Ubuntu-compatible Tiling Assistant where supported.

Support:

- snapping
- edge tiling
- quarter tiling
- keyboard shortcuts
- maximize
- restore
- drag-to-tile

Do not install overlapping tiling extensions.

Detect conflicts.

---

# 22. ANIMATIONS

Enable GNOME animations.

Configure sensible Ubuntu-like behavior.

Do NOT apply extreme animations that make the desktop slower.

---

# 23. KEYBOARD SHORTCUTS

Implement Ubuntu-like shortcuts.

Examples:

```text
Super
Super+A
Super+L
Super+E
Alt+F2
Super+Left
Super+Right
Super+Up
Super+Down
```

Also configure workspace shortcuts.

Before changing custom shortcuts:

1. backup existing shortcuts
2. detect conflicts
3. warn if a shortcut is already used
4. allow user to keep or replace it

---

# 24. APPLICATION FAVORITES

Configure Ubuntu-like favorites.

Possible default set:

```text
Files
Firefox
Terminal
Settings
Software
```

But DO NOT assume every application exists.

Detect desktop files.

For example:

```text
✓ org.gnome.Nautilus.desktop
✓ firefox.desktop
✓ org.gnome.Console.desktop
✓ org.gnome.Settings.desktop
```

Only add applications that actually exist.

---

# 25. NAUTILUS

Configure GNOME Files to behave similarly to Ubuntu.

Support:

- icon view
- thumbnails
- sidebar
- bookmarks
- default locations
- mounted drives
- trash
- context menu behavior

Do not modify system Nautilus binaries.

---

# 26. DEFAULT APPLICATIONS

Detect available applications.

Do not force-install unnecessary applications.

Allow:

```bash
ubuntuify defaults
```

to configure sensible defaults.

Examples:

```text
Browser → Firefox
File manager → Nautilus
Terminal → GNOME Console
Text editor → GNOME Text Editor
```

Only configure applications that exist.

---

# 27. WALLPAPER

Provide Ubuntu-style wallpaper support.

Do not replace the user's wallpaper without warning.

Offer:

```text
Use Ubuntu-style wallpaper
Keep current wallpaper
Choose wallpaper
```

Store project wallpapers in a safe user directory:

```text
~/.local/share/ubuntuify/wallpapers/
```

Do not overwrite:

```text
/usr/share/backgrounds
```

unless explicitly required.

---

# 28. DARK MODE

Provide:

```bash
ubuntuify profile dark
```

and:

```bash
ubuntuify profile light
```

Dark mode should configure:

- GTK
- icons
- Shell
- applications where supported
- dock
- wallpaper
- system appearance

Keep the entire desktop visually consistent.

---

# 29. SOUND THEME

Where supported, configure Yaru sound theme.

Do not modify system audio configuration.

---

# 30. GDM / LOGIN SCREEN

Investigate what can safely be configured on Fedora.

If a change requires modifying GDM system files:

- clearly warn
- create backup
- require explicit confirmation
- provide rollback

Never blindly overwrite GDM configuration.

Prefer supported configuration.

---

# 31. PLYMOUTH

Provide optional Ubuntu-style Plymouth branding.

This must be:

```bash
ubuntuify install --component plymouth
```

and NOT enabled automatically.

Before modifying Plymouth:

- verify Fedora Plymouth installation
- backup existing configuration
- explain consequences
- rebuild initramfs only when necessary
- verify commands exist

Provide:

```bash
ubuntuify restore --component plymouth
```

---

# 32. SYSTEM TRAY / LEGACY APPLICATIONS

Support AppIndicator/KStatusNotifierItem.

Detect whether applications are using:

- StatusNotifierItem
- AppIndicator
- legacy tray APIs

Do not attempt to modify individual applications.

---

# 33. EXTENSION MANAGER

Build an extension manager.

It must know:

```text
Extension
Installed?
Enabled?
Compatible?
Required?
Optional?
Conflicting?
```

Example:

```text
AppIndicator
  Installed: YES
  Enabled: YES
  Compatible: YES

Desktop Icons NG
  Installed: YES
  Enabled: YES
  Compatible: YES

Dash to Dock
  Installed: YES
  Enabled: YES
  Compatible: YES

Tiling Assistant
  Installed: YES
  Enabled: NO
  Compatible: YES
```

Do not enable incompatible extensions.

---

# 34. GNOME VERSION COMPATIBILITY

This is extremely important.

Never assume:

```text
GNOME 45
GNOME 46
GNOME 47
GNOME 48
GNOME 49
GNOME 50
```

have identical schemas.

Before executing a GSettings command:

```bash
gsettings list-schemas
```

Check the schema exists.

Before setting a key:

```bash
gsettings list-keys <schema>
```

Check that the key exists.

Before setting a value:

```bash
gsettings range <schema> <key>
```

where appropriate.

If unsupported:

```text
⚠ Setting unavailable on this GNOME version.
Skipping safely.
```

Never crash the entire installer because one optional setting is unavailable.

---

# 35. WAYLAND

Wayland is the primary target.

Do not rely on:

```text
xdotool
wmctrl
X11-only APIs
```

unless they are explicitly optional.

Prefer:

- GSettings
- D-Bus
- GNOME Shell extensions
- desktop portals
- system APIs

---

# 36. GNOME EXTENSION COMPATIBILITY

Never blindly download extension ZIP files.

Prefer:

1. Fedora packages
2. official GNOME extension infrastructure
3. official upstream repositories

Only use third-party repositories when absolutely necessary.

Verify downloads.

---

# 37. SECURITY

The project must follow secure coding practices.

Never:

```bash
curl ... | bash
```

Never execute arbitrary downloaded scripts.

Validate URLs.

Use HTTPS.

Verify packages using Fedora's package manager.

Quote shell variables.

Use:

```bash
set -Eeuo pipefail
```

where appropriate.

Avoid:

```bash
eval
```

unless absolutely unavoidable.

Do not store passwords.

Do not collect telemetry.

No network calls should occur unless necessary for installation/update.

---

# 38. ROOT PRIVILEGES

The main application should run as the normal user.

Use `sudo` only for operations requiring root.

Never run the entire application as root.

Clearly separate:

```text
USER operations
ROOT operations
```

---

# 39. ERROR HANDLING

If one component fails:

```text
❌ Dash configuration failed
```

do NOT leave the entire desktop half-configured without explaining what happened.

Implement:

- error trapping
- logging
- rollback where possible
- clear error messages
- recovery instructions

Log to:

```text
~/.local/share/ubuntuify/logs/
```

---

# 40. DOCTOR COMMAND

Implement:

```bash
ubuntuify doctor
```

It should check:

```text
OS
Fedora version
GNOME version
Wayland/X11
Architecture
DNF
GSettings
DConf
GNOME Extensions
Yaru
Fonts
AppIndicator
DING
Dash to Dock
Tiling Assistant
GDM
Plymouth
Disk space
Permissions
```

Example:

```text
Ubuntuify Doctor

✓ Fedora detected
✓ GNOME detected
✓ Wayland detected
✓ DNF available
✓ GSettings available
✓ DConf available
✓ Yaru installed
✓ Ubuntu fonts installed
✓ AppIndicator installed
✓ DING installed
✓ Dash to Dock installed
✓ Tiling Assistant installed

No critical problems found.
```

---

# 41. STATUS COMMAND

Implement:

```bash
ubuntuify status
```

Output:

```text
Ubuntuify Status
────────────────────────────

Profile:
  Ubuntu Full

Theme:
  GTK: Yaru
  Icons: Yaru
  Cursor: Yaru

Dock:
  Position: Left
  Size: 48
  Fixed: Yes

Desktop Icons:
  Home: Yes
  Trash: Yes
  Volumes: Yes

Tray:
  AppIndicator: Enabled

GNOME:
  Version: 50.x
  Session: Wayland

Backup:
  Available: Yes

Overall:
  Ubuntuified ✓
```

---

# 42. UPDATE COMMAND

Implement:

```bash
ubuntuify update
```

It should:

- detect current Fedora version
- detect GNOME version
- check extension compatibility
- update supported components
- preserve user customizations where possible
- never overwrite user modifications unnecessarily

If GNOME has changed significantly:

```text
⚠ GNOME version changed from 50 to 51.

Some extensions may require migration.

Run:

ubuntuify doctor
```

---

# 43. RESET

Implement:

```bash
ubuntuify reset
```

It should reset only Ubuntuify-managed configuration.

Do not erase unrelated GNOME settings.

---

# 44. UNINSTALL

Implement:

```bash
ubuntuify uninstall
```

It should:

- disable Ubuntuify-managed extensions
- restore previous configuration
- remove Ubuntuify-managed configuration
- optionally remove packages installed solely by Ubuntuify

Do NOT automatically remove packages that may have existed before Ubuntuify.

Track packages installed by Ubuntuify.

Example:

```text
ubuntuify package state

Installed before Ubuntuify:
  gnome-tweaks

Installed by Ubuntuify:
  yaru-theme
  fonts-ubuntu
  ...
```

Only remove packages from the second category when the user explicitly requests package cleanup.

---

# 45. STATE TRACKING

Maintain a state file.

Example:

```text
~/.local/share/ubuntuify/state.json
```

Track:

```json
{
  "version": "1.0.0",
  "fedora_version": "44",
  "gnome_version": "50",
  "session": "wayland",
  "installed_packages": [],
  "enabled_extensions": [],
  "profile": "full",
  "backup": "2026-11-19-170000"
}
```

Do not trust this blindly.

Always verify the actual system state.

---

# 46. PROFILES

Implement profiles.

### Full

Everything supported.

```text
Theme
Dock
Desktop Icons
Tray
Tiling
Shortcuts
Nautilus
Favorites
Wallpaper
Sound
GNOME behavior
Optional boot branding
```

### Minimal

Only visual changes:

```text
Yaru
Icons
Cursor
Fonts
Wallpaper
```

### Dark

Ubuntu dark experience.

### Classic

More conservative Ubuntu-style desktop.

### Custom

Allow the user to choose individual components.

---

# 47. CONFIGURATION FILE

Allow advanced users to customize:

```text
~/.config/ubuntuify/config.conf
```

Example:

```ini
profile=full

theme=yaru
color_scheme=dark

dock.position=left
dock.icon_size=48
dock.autohide=false

desktop_icons.home=true
desktop_icons.trash=true
desktop_icons.volumes=true

tray=true
tiling=true

ubuntu_shortcuts=true

wallpaper=ubuntu-default

plymouth=false
gdm=false
```

---

# 48. DO NOT DESTROY CUSTOMIZATIONS

If the user has already customized GNOME:

```text
theme
dock
extensions
shortcuts
wallpaper
favorites
```

do not silently destroy everything.

Before replacing:

```text
Your current GNOME configuration differs from Ubuntuify defaults.

[1] Replace
[2] Merge
[3] Keep current
[4] Cancel
```

For automated mode, use predictable behavior.

---

# 49. DRY RUN

Implement:

```bash
ubuntuify install --dry-run
```

It should show:

```text
Would install:
  yaru-theme
  fonts-ubuntu

Would enable:
  AppIndicator
  Desktop Icons NG
  Dash to Dock
  Tiling Assistant

Would change:
  GTK theme
  icon theme
  dock position
  favorites
  shortcuts

No changes made.
```

---

# 50. NON-INTERACTIVE MODE

Support:

```bash
ubuntuify install --yes
```

for automation.

Also:

```bash
ubuntuify install --profile full --yes
```

No interactive prompts.

---

# 51. TESTING

Create tests.

At minimum:

### Unit tests

Test:

- Fedora detection
- GNOME detection
- package detection
- schema detection
- extension detection
- backup creation
- configuration parsing
- CLI parsing

### Integration tests

Test against a disposable Fedora VM.

Verify:

```text
install
status
doctor
restore
uninstall
```

Do not test only on the developer's machine.

---

# 52. VIRTUAL MACHINE TESTING

Document a recommended VM testing workflow.

Use:

```text
Fedora Workstation VM
GNOME
Wayland
Snapshot before install
```

Test:

```text
Fresh Fedora
↓
ubuntuify install
↓
reboot
↓
verify desktop
↓
ubuntuify status
↓
ubuntuify doctor
↓
ubuntuify restore
↓
reboot
↓
verify original desktop
```

---

# 53. README

Write a professional README.

Include:

```text
# Ubuntuify Fedora

Transform Fedora GNOME into an Ubuntu-like desktop experience.

Features
Screenshots
Requirements
Installation
Usage
Profiles
Components
Rollback
Troubleshooting
Compatibility
Security
Development
Contributing
License
```

Include screenshots placeholders.

---

# 54. INSTALLATION

Support:

```bash
git clone <repository>
cd ubuntuify-fedora
./ubuntuify install
```

Do not require users to manually edit dozens of files.

---

# 55. HELP

Implement:

```bash
ubuntuify help
```

Output useful command documentation.

Also support:

```bash
ubuntuify install --help
ubuntuify doctor --help
ubuntuify restore --help
```

---

# 56. VERSIONING

Use semantic versioning:

```text
MAJOR.MINOR.PATCH
```

Example:

```text
1.0.0
```

---

# 57. LOGGING

Every operation should be logged.

Example:

```text
2026-11-19 17:00:01 INFO Starting Ubuntuify
2026-11-19 17:00:02 INFO Fedora 44 detected
2026-11-19 17:00:02 INFO GNOME 50 detected
2026-11-19 17:00:03 INFO Creating backup
2026-11-19 17:00:08 INFO Installing Yaru
2026-11-19 17:00:14 INFO Enabling AppIndicator
2026-11-19 17:00:15 INFO Configuring Dash to Dock
```

---

# 58. TERMINAL OUTPUT

Use clear output:

```text
[INFO]
[OK]
[WARN]
[ERROR]
[SKIP]
```

Do not flood the terminal with unnecessary output.

---

# 59. ACCESSIBILITY

Do not make the project unusable for:

- screen readers
- keyboard-only users
- high contrast users
- reduced-motion users

Respect GNOME accessibility preferences.

Do not force animations if the user has reduced motion enabled.

---

# 60. INTERNATIONALIZATION

Avoid hardcoding assumptions about language.

Do not assume:

```text
English
US keyboard
US locale
```

The tool must work on systems using:

```text
French
Arabic
English
Spanish
etc.
```

Do not replace the user's locale.

---

# 61. LOCALE

Never change:

```text
LANG
LC_ALL
LC_TIME
LC_MONETARY
```

unless explicitly requested.

Ubuntuify is a desktop appearance project, not a locale migration tool.

---

# 62. NETWORK

The installer should have a clear list of external resources it may access.

Prefer Fedora repositories and official upstream sources.

Do not silently send telemetry.

Do not phone home.

---

# 63. PERFORMANCE

The resulting desktop should remain performant.

Avoid installing:

- unnecessary background services
- duplicate daemons
- RAM-heavy extensions
- unnecessary GNOME extensions

The project should optimize for:

```text
low CPU
low RAM
minimal startup impact
```

---

# 64. POWER MANAGEMENT

Do not overwrite Fedora's power-management system.

Only configure GNOME-level preferences where appropriate.

Never disable:

```text
power-profiles-daemon
thermald
systemd-logind
```

without a very good reason.

---

# 65. LAPTOP SUPPORT

Ensure Ubuntuify works on laptops.

Do not break:

- touchpad
- touchscreen
- brightness
- battery
- suspend
- lid behavior
- external monitors
- Bluetooth
- Wi-Fi

---

# 66. MULTI-MONITOR

Dock configuration must support multiple monitors where the extension supports it.

Do not assume one monitor.

Detect:

```text
primary monitor
secondary monitor
monitor count
```

and configure accordingly.

---

# 67. NVIDIA

Do not modify NVIDIA drivers.

Do not install GPU drivers.

Ubuntuify must work independently of GPU vendor.

---

# 68. GNOME EXTENSION CONFLICT DETECTION

Detect conflicts such as:

```text
Dash to Dock
Dash to Panel
Ubuntu Dock
ArcMenu
Just Perfection
other dock extensions
other desktop icon extensions
```

Do not blindly disable unrelated extensions.

Show:

```text
Potential conflict detected:

Dash to Panel

Ubuntuify requires Dash to Dock.

[1] Disable Dash to Panel
[2] Keep Dash to Panel
[3] Cancel
```

---

# 69. UBUNTU DOCK VS DASH TO DOCK

Where Fedora provides a compatible Ubuntu dock implementation, prefer it.

Otherwise configure Dash to Dock to reproduce Ubuntu behavior.

Do not install both simultaneously.

---

# 70. SYSTEM INTEGRATION

Use standard Linux mechanisms:

```text
GSettings
DConf
D-Bus
XDG Desktop Entry
systemd user services only where necessary
```

Avoid hacks.

---

# 71. DESKTOP FILES

When adding applications to favorites, use actual `.desktop` files.

Search:

```text
/usr/share/applications
~/.local/share/applications
```

Never fabricate desktop file names.

---

# 72. COMMAND SAFETY

Every command modifying the system must be reviewed.

Avoid dangerous commands such as:

```bash
rm -rf /
```

or unrestricted recursive deletes.

Never use:

```bash
rm -rf "$variable"
```

without validating the path.

---

# 73. ROOT COMMAND SAFETY

Prefer:

```bash
sudo dnf install ...
```

instead of:

```bash
sudo bash
```

Do not maintain a persistent root shell.

---

# 74. RECOVERY

If the desktop becomes unusable, provide recovery instructions.

For example:

```text
CTRL+ALT+F3
login
ubuntuify restore
```

Also document how to disable problematic GNOME extensions manually.

---

# 75. GNOME SHELL RESTART

Do NOT tell Wayland users to use:

```text
Alt+F2 → r
```

as a universal solution.

That is not appropriate for modern Wayland GNOME.

Prefer:

```text
logout/login
reboot
```

when required.

---

# 76. UBUNTU EXPERIENCE SCORE

Implement a diagnostic score.

Example:

```text
Ubuntu Experience

Theme             ██████████ 100%
Dock              ██████████ 100%
Desktop Icons     ██████████ 100%
System Tray       ██████████ 100%
Shortcuts         █████████░  90%
Window Behavior   █████████░  90%
Boot Experience   ███░░░░░░░  30%

Overall:
91% Ubuntu-like
```

This is only a UX indicator, not a technical benchmark.

---

# 77. COMPONENT STATUS

Allow:

```bash
ubuntuify status --components
```

Output:

```text
Theme             ✓
Icons             ✓
Cursor            ✓
Fonts             ✓
Dock              ✓
Desktop Icons     ✓
AppIndicator      ✓
Tiling            ✓
Shortcuts         ✓
Nautilus          ✓
Wallpaper         ✓
Sound             ✓
Plymouth          ○
GDM               ○
```

---

# 78. DOCUMENTATION FOR LIMITATIONS

Be honest.

Some Ubuntu behavior may be impossible to reproduce exactly because Ubuntu patches GNOME or ships components differently.

Document:

```text
Exact Ubuntu GNOME
████████████████████████████████

Fedora + Ubuntuify
████████████████████████████░░░░

Remaining differences:
- Ubuntu-specific downstream GNOME patches
- certain GDM integration
- Ubuntu-specific system components
- distribution-specific package integration
```

Do not claim "100% identical Ubuntu" unless technically verified.

The goal is:

> Maximum possible Ubuntu GNOME fidelity without turning Fedora into Ubuntu.

---

# 79. OPEN-SOURCE QUALITY

Code must be:

- readable
- modular
- commented
- documented
- maintainable
- auditable

Do not create giant functions.

Use functions with one responsibility.

---

# 80. SHELL STYLE

Use:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

Use shellcheck-compatible Bash.

Avoid unnecessary subshells.

Quote variables.

Check commands:

```bash
command -v
```

before using them.

---

# 81. PYTHON STYLE

If Python is used:

- Python 3
- standard library preferred
- type hints where useful
- argparse
- pathlib
- subprocess with explicit arguments
- no unsafe shell execution
- clear error handling

---

# 82. GIT

Use sensible commits:

```text
feat: add Fedora environment detection
feat: add backup system
feat: add Yaru configuration
feat: add dock configuration
feat: add AppIndicator support
feat: add desktop icon support
feat: add doctor command
test: add GNOME schema detection
docs: add installation guide
```

---

# 83. LICENSE

Use a permissive open-source license such as MIT unless there is a strong reason otherwise.

Respect licenses of Ubuntu/Yaru assets and third-party projects.

Do not copy copyrighted Ubuntu assets into the repository without checking their licensing.

Prefer installing official packages rather than redistributing assets.

---

# 84. NO COPYRIGHT MISREPRESENTATION

The project is independent.

Do not claim:

```text
Official Ubuntu project
```

Use wording such as:

> Ubuntuify Fedora is an independent community project inspired by the Ubuntu GNOME desktop experience.

---

# 85. FINAL IMPLEMENTATION REQUIREMENT

Do not stop after generating an architecture document.

Actually implement the project.

At the end provide:

1. Complete project tree
2. Complete source files
3. Installation instructions
4. Usage instructions
5. Testing instructions
6. Rollback instructions
7. Compatibility notes
8. Known limitations
9. README
10. Example configuration
11. Example output
12. Development instructions

Do not leave core functionality as:

```text
TODO
implement later
placeholder
```

Implement the important functionality.

If a feature cannot safely be implemented, create a graceful detection/fallback mechanism instead.

---

# 86. DEVELOPMENT PRIORITY

Implement in this order:

### Phase 1

```text
CLI
Environment detection
Logging
Backup
Restore
State management
```

### Phase 2

```text
Yaru
Fonts
Icons
Cursor
Appearance
```

### Phase 3

```text
AppIndicator
Desktop Icons NG
Dash to Dock
Tiling Assistant
```

### Phase 4

```text
Panel
Shortcuts
Workspaces
Window behavior
Nautilus
Favorites
```

### Phase 5

```text
Doctor
Status
Update
Profiles
Conflict detection
```

### Phase 6

```text
Optional Plymouth
Optional GDM
Advanced customization
```

### Phase 7

```text
Testing
Documentation
Packaging
Release preparation
```

---

# 87. IMPORTANT: RESEARCH BEFORE IMPLEMENTATION

Before implementing GNOME-specific behavior, inspect the current Fedora/GNOME environment and official/current documentation.

Do not rely on old GNOME 40/41 tutorials.

Check:

```bash
gnome-shell --version
gsettings list-schemas
gsettings list-recursively
gnome-extensions list
rpm -qa
dnf info <package>
```

Use the currently installed GNOME version as the source of truth.

If an Ubuntu extension has changed its schema, adapt to the current version.

---

# 88. FINAL ACCEPTANCE TEST

The project is considered successful when this works on a fresh Fedora GNOME installation:

```bash
git clone <repo>
cd ubuntuify-fedora

./ubuntuify install
```

Then after logout/login:

```text
✓ Yaru theme
✓ Ubuntu-style icons
✓ Ubuntu cursor
✓ Ubuntu fonts
✓ Ubuntu-style dock
✓ Applications button
✓ Desktop icons
✓ Home icon
✓ Trash icon
✓ Mounted volume icons
✓ AppIndicator tray
✓ Ubuntu-style shortcuts
✓ Ubuntu-style window behavior
✓ Tiling
✓ Ubuntu-like favorites
✓ Ubuntu-like GNOME behavior
✓ Ubuntu-like wallpaper
✓ GNOME Files configuration
```

Then:

```bash
ubuntuify doctor
```

must report no critical errors.

Then:

```bash
ubuntuify restore
```

must restore the user's previous GNOME configuration.

The user must be able to reboot and continue using Fedora normally.

---

# 89. MOST IMPORTANT REQUIREMENT

Think like a Linux distribution engineer.

Do not merely make Fedora "look purple."

The project should reproduce the **Ubuntu GNOME user experience** as deeply as technically possible while preserving Fedora's identity underneath.

Prioritize:

```text
behavior
integration
compatibility
reversibility
safety
performance
```

over superficial visual modifications.

Build it as something that could realistically be published on GitHub and used by other Fedora users.

Start by inspecting the current repository/environment, then implement Phase 1 through Phase 7 systematically.

Do not ask unnecessary questions. Make reasonable engineering decisions and document them.
