# Installation

## Supported systems

- Fedora Workstation 44 or newer.
- GNOME Shell 45 or newer (the code detects the version and does not hard-code
  extension versions).
- A normal user account with a GNOME session. Wayland is the primary target;
  X11 is supported for GSettings-based components.

Ubuntuify does not replace repositories, `/etc/os-release`, DNF, RPM, the
kernel or systemd, and it does not install Debian packages.

## From a git checkout

```bash
git clone <repository> ubuntuify-fedora
cd ubuntuify-fedora
./ubuntuify doctor
./ubuntuify install --dry-run
./ubuntuify install
```

`./ubuntuify` is a Bash launcher; there is no build step, no `pip install` and
no external TUI framework. Python 3 is required for state/JSON/GVariant helpers
and is already present on Fedora Workstation.

To use the command from any directory:

```bash
mkdir -p ~/.local/bin
ln -sf "$PWD/ubuntuify" ~/.local/bin/ubuntuify
# ~/.local/bin must be on PATH
```

After installing, log out and back in (or reboot). GNOME Shell loads themes and
extensions at login; Wayland does not support Alt+F2 `r`.

## Recommended first run

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

## Non-interactive installation

```bash
./ubuntuify install --yes
```

`--yes` accepts normal prompts but deliberately **never** downloads an
extension from extensions.gnome.org. If Desktop Icons NG or another extension
is not packaged by Fedora, it is skipped. Use `--online-extensions` explicitly
if you want the fallback:

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

## Configuration before installing

Copy the sample and edit only the keys you need:

```bash
mkdir -p ~/.config/ubuntuify
./ubuntuify config --sample > ~/.config/ubuntuify/config.conf
${EDITOR:-vi} ~/.config/ubuntuify/config.conf
./ubuntuify config          # show effective values
./ubuntuify install
```

User configuration overrides shipped defaults; command-line flags override the
user configuration. Unknown keys are ignored, invalid values are rejected or
replaced by the documented default, and values are never written blindly. The
file is parsed, never sourced, so it cannot execute commands.

## Optional boot branding

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

## Verifying

```bash
./ubuntuify status
./ubuntuify status --components
./ubuntuify doctor
```

`doctor` exits non-zero when it finds critical errors. Warnings for known Fedora
packaging gaps (Ubuntu fonts, Yaru cursor, Desktop Icons NG) are expected on
releases where those packages are absent. See
[docs/troubleshooting.md](docs/troubleshooting.md) if a component is skipped.

## Updating

```bash
git pull
./ubuntuify update
```

`update` re-applies the recorded profile and reports Fedora/GNOME version
changes. It does not add boot components or enable the online extension
fallback.

## Uninstalling

```bash
./ubuntuify uninstall
```

This restores the recorded original settings, disables extensions Ubuntuify
enabled, removes generated wallpapers/cache/state and keeps backups and logs.
Packages are kept unless you ask for removal:

```bash
./ubuntuify uninstall --remove-packages
```

If the state is missing but backups exist, uninstall tells you to use
`./ubuntuify restore --backup <id>` instead of guessing. See
[docs/rollback.md](docs/rollback.md).

## Requirements checklist

| Tool | Purpose | Required |
| --- | --- | --- |
| `python3` | State, GVariant, extension and artwork helpers | yes |
| `gsettings` (glib2) | Desktop configuration | yes |
| `dconf` | Backups and full restore | recommended |
| `dnf`, `rpm` | Package installation and detection | yes |
| `sudo` | Package and boot-branding operations | for those operations |
| `gnome-extensions` | Enabling shell extensions | recommended |
| `curl` | Opt-in extensions.gnome.org fallback | optional |
| `fc-list` | Font detection | optional (fonts skipped without it) |

## Security notes

- Run Ubuntuify as your normal user, never as root.
- `sudo` is used only for individual package/boot commands.
- No telemetry, no credentials, no downloaded script execution.
- Extension downloads are HTTPS-only and validated before install.

See [SECURITY.md](SECURITY.md).
