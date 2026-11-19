# Backup and rollback

Ubuntuify is designed so that every change can be undone. There are four
different rollback levels; use the smallest one that solves the problem.

| Command | What it does |
| --- | --- |
| `ubuntuify restore --component NAME` | Reverts only the settings recorded for one component. |
| `ubuntuify restore` | Restores the newest complete backup (dconf + state). |
| `ubuntuify reset` | Reverts Ubuntuify-managed settings, preserving later user edits. |
| `ubuntuify uninstall` | Reverts managed settings, removes extensions/wallpaper data and state. |

## Backups

A backup is created automatically before installing a profile and when the
profile changes. `--backup-now` forces a new one even when the existing profile
is unchanged; `--no-backup` skips the automatic snapshot.

```bash
./ubuntuify backup
./ubuntuify restore
./ubuntuify restore --backup 2026-11-19-171500
```

Backups live in `~/.local/share/ubuntuify/backups/<timestamp>/`:

```text
meta.txt                  reason, versions, session, date
dconf.dump                dconf dump /
gsettings.dump            gsettings list-recursively
extensions-installed.txt
extensions-enabled.txt
extensions-disabled.txt
favorites.txt
packages-before.txt
state.json                Ubuntuify state at snapshot time
original-settings.tsv
applied-settings.tsv
user-config.tar           ~/.config/gtk-3.0, gtk-4.0, nautilus, ubuntuify, ...
checksums.sha256
```

Backups are timestamped and never overwritten. The newest 10 are kept by
default (`backup.keep`); the active backup is never pruned.

`restore` verifies that the backup exists, has metadata, contains at least one
restorable settings source and passes its checksum manifest before changing
anything.

## Full restore

```bash
./ubuntuify restore                 # newest backup
./ubuntuify restore --backup ID     # specific backup
```

Full restore:

1. asks for confirmation (unless `--yes`/dry-run);
2. loads the saved `dconf` dump, which restores GSettings, extensions,
   favorites, shortcuts and appearance;
3. if dconf is unavailable or the dump cannot be loaded, falls back to the
   recorded original settings;
4. restores the archived user configuration files;
5. restores the recorded state, so `status` reflects the rollback;
6. clears the transaction logs.

Packages are **not** removed by `restore`. Theme packages can remain installed
harmlessly; use `uninstall --remove-packages` for cleanup.

After restore, log out and back in (or reboot). On Wayland, Alt+F2 `r` does not
restart GNOME Shell.

## Component restore

```bash
./ubuntuify restore --component theme
./ubuntuify restore --component dock
./ubuntuify restore --component desktop-icons
./ubuntuify restore --component shortcuts
```

Component restore reads `original-settings.tsv` and restores only entries whose
component matches. It does not load the dconf dump, so unrelated settings are
untouched. Original values are recorded only once, at the first change, so a
component restore returns to the pre-Ubuntuify value rather than an
intermediate profile.

The `plymouth` and `gdm` components have dedicated restore functions that
remove files installed under `/usr/share` and restore the previous theme/login
background.

## Reset vs restore

`reset` is for "I want Fedora's desktop back but want to keep changes I made
after installing". It compares the current value with the applied value:

- if they match, the original is restored;
- if the user changed it afterwards, the user's value is preserved and the
  setting is reported as skipped.

`restore` is stronger: it replaces the whole desktop state with the snapshot.

## Uninstall

```bash
./ubuntuify uninstall
./ubuntuify uninstall --remove-packages
```

Uninstall:

1. disables extensions Ubuntuify enabled;
2. restores Plymouth/GDM if those components are present;
3. restores every recorded original setting;
4. optionally removes packages recorded as installed by Ubuntuify (never
   packages that existed before);
5. removes generated wallpapers, cache and state;
6. keeps backups and logs under `~/.local/share/ubuntuify/`.

If state is missing but backups exist, uninstall refuses to guess and tells you
to use `restore` instead.

## Interrupted installs

Settings are written through the transaction log as they are applied. If the
process is interrupted, run:

```bash
./ubuntuify doctor
./ubuntuify restore
```

The `ERR` trap reports the failing line and exits non-zero; the lock is released
when the process exits, so a later run is not blocked. The settings already
changed remain recorded and can be restored.

## Boot branding rollback

Plymouth and GDM are opt-in and require `sudo`. Both components back up the
existing theme/configuration before installation.

```bash
./ubuntuify restore --component plymouth
./ubuntuify restore --component gdm
```

Run these from an interactive terminal so `sudo` can prompt. If the graphical
boot breaks and you need a rescue shell, switch to a TTY (Ctrl+Alt+F3), log in,
and run the component restore from the checkout. The original Plymouth theme
name is recorded in Ubuntuify state and in the backup metadata.

## Emergency manual rollback

If the CLI itself is unavailable:

```bash
# Restore the newest dconf snapshot directly
dconf load / < ~/.local/share/ubuntuify/backups/<ID>/dconf.dump

# Or revert only recorded settings
while IFS=$'\t' read -r component schema key value; do
  gsettings set "$schema" "$key" "$value" 2>/dev/null || true
done < ~/.local/share/ubuntuify/state/original-settings.tsv

# Disable extensions Ubuntuify enabled
gsettings get org.gnome.shell enabled-extensions
```

Do not delete `/usr/share/themes` or `/usr/share/icons`; those are package-owned
and may be shared with other desktops.
