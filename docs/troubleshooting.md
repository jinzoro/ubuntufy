# Troubleshooting

Run diagnostics first:

```bash
./ubuntuify doctor
./ubuntuify status
./ubuntuify status --components
```

Every operation writes a timestamped log to
`~/.local/share/ubuntuify/logs/`. The newest log is usually the most useful:

```bash
ls -1t ~/.local/share/ubuntuify/logs | head
tail -n 100 ~/.local/share/ubuntuify/logs/<newest>.log
```

## "Settings schema unavailable" / "Setting unavailable"

Ubuntuify refuses to write keys that the running GNOME Shell does not expose.
This is expected on:

- an older Fedora/GNOME release than the component was written for;
- a non-GNOME session (KDE, a bare TTY, a container without a session bus);
- a very new GNOME release where a key was renamed or removed.

The affected setting is skipped and counted, not fatal. Check the live schema:

```bash
gsettings list-schemas | grep org.gnome.desktop.interface
gsettings list-keys org.gnome.desktop.interface
gsettings range org.gnome.desktop.interface color-scheme
```

If the key exists but the value is rejected, the `[SKIP] Value ... is not
allowed` line shows the accepted range.

## Themes or icons did not change

1. Log out and back in. GNOME Shell caches the theme and extensions; Wayland
   does not support Alt+F2 `r`.
2. Verify the theme is actually installed:

   ```bash
   ls /usr/share/themes/Yaru/gtk-3.0
   ls /usr/share/icons/Yaru/index.theme
   ```

3. Re-apply only the visual layer:

   ```bash
   ./ubuntuify install --component theme
   ./ubuntuify install --component icons
   ```

4. Check the current values:

   ```bash
   gsettings get org.gnome.desktop.interface gtk-theme
   gsettings get org.gnome.desktop.interface icon-theme
   gsettings get org.gnome.desktop.interface color-scheme
   ```

Some Fedora releases package `yaru-theme` with GTK/icons/sound but no GNOME
Shell theme. Ubuntuify leaves the Fedora shell theme in place rather than
installing an incompatible one.

## Ubuntu fonts or the Yaru cursor are missing

These are known Fedora packaging gaps. `[WARN]` lines such as "Ubuntu fonts are
not available from Fedora repositories" mean the current fonts/cursor were kept
intentionally. The rest of the profile still applies. Do not force a theme that
does not exist; font fallback is preferable to broken rendering.

## Desktop icons / dock / tray are not active

The extension may be installed but not enabled until the next login:

```bash
gnome-extensions list
gnome-extensions list --enabled
gnome-extensions info ding@rastersoft.com
```

Then:

```bash
gnome-extensions enable ding@rastersoft.com
# or log out and back in
```

If the extension is absent, check the Fedora gap and the EGO fallback policy:

```bash
dnf info gnome-shell-extension-desktop-icons-ng
./ubuntuify install --component desktop-icons --online-extensions
```

`--yes` deliberately refuses the EGO fallback. Run interactively or set
`online_extensions=yes` in the config if you want it in automation.

## "Another Ubuntuify process is already running"

A previous run still holds `~/.local/share/ubuntuify/.lock`. Wait for it to
finish. If it was killed and the lock is stale, check that no `ubuntuify`
process is running, then remove the lock file:

```bash
pgrep -af ubuntuify
rm -f ~/.local/share/ubuntuify/.lock
```

Do not delete state or backups while troubleshooting; they are needed for
rollback.

## A shortcut was not changed

`shortcuts.on_conflict` controls what happens when a key already has a binding:

- `keep` (default) leaves the existing binding;
- `ask` prompts;
- `replace` replaces it.

Ubuntuify also detects custom keybindings that use the same accelerator and
skips the Ubuntu shortcut with a warning. Inspect the current binding:

```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys terminal
gsettings get org.gnome.desktop.wm.keybindings maximize
```

## Plymouth or GDM component fails

Both need root and an interactive terminal:

```bash
sudo -v
./ubuntuify install --component plymouth
./ubuntuify install --component gdm
```

`uf_require_sudo` refuses non-interactive sessions without passwordless sudo.
If the graphical boot is already broken, switch to a TTY (Ctrl+Alt+F3), log in,
and run `./ubuntuify restore --component plymouth` or `--component gdm` from
the checkout.

Never remove package-owned files under `/usr/share/plymouth` or
`/usr/share/gnome-shell` by hand.

## Restore says "Backup contains no restorable desktop settings"

The backup has metadata but no non-empty dconf dump, GSettings dump or
`original-settings.tsv`. This can happen in a container without a session bus,
or if the backup was taken before GNOME was available. Use a component restore
from the live state, or take a new backup in a real GNOME session.

## Restore says checksum verification failed

A backup file was modified or truncated. Do not use that backup. Try an older
one:

```bash
ls ~/.local/share/ubuntuify/backups
./ubuntuify restore --backup <older-id>
```

## GSettings works but nothing changes in the shell

Extensions and shell themes are loaded by GNOME Shell, not by `gsettings`.
Log out and back in. On Wayland, `Alt+F2` then `r` does not restart the shell.
If you are in a nested/container session, changes apply to that session's dconf
database, which may not be the one your desktop uses.

## After a Fedora/GNOME upgrade

Run:

```bash
./ubuntuify doctor
./ubuntuify update
```

`update` re-applies the recorded profile and warns when the Fedora or GNOME
version changed. Extensions that no longer declare support for the new GNOME
major version are not enabled. They can be replaced or skipped; see
[extensions.md](extensions.md).

## Uninstall did not restore everything

Check that state exists:

```bash
./ubuntuify status
ls ~/.local/share/ubuntuify/state
```

If state was removed but backups remain, uninstall intentionally refuses to
guess. Run `./ubuntuify restore --backup <id>` to load a snapshot, then
uninstall again.

Component restores only touch settings recorded for that component. Settings
changed by other tools after install are preserved by `reset`, but a full
`restore` replaces the whole dconf snapshot.

## Reporting a problem

Include:

- Fedora version (`cat /etc/fedora-release`);
- GNOME version (`gnome-shell --version`);
- session type (`echo "$XDG_SESSION_TYPE"`);
- `./ubuntuify doctor` output;
- the relevant log lines, with personal paths redacted.

Do not paste dconf dumps or backups publicly without checking them for private
data.
