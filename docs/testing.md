# Testing

There are two layers: a fast, fully sandboxed suite you can run anywhere, and
manual acceptance testing on a disposable Fedora GNOME VM. The automated suite
cannot prove that GNOME Shell renders a theme; the VM test can.

## Automated suite

```bash
bash tests/run.sh
```

Each `tests/unit/*.sh` and `tests/integration/*.sh` file runs in its own Bash
process. The harness:

- creates a temporary `HOME` and XDG directories before sourcing `src/lib.sh`,
  so no test can read or write your real desktop state;
- puts `tests/mocks` first on `PATH`, replacing `gsettings`, `dconf`, `dnf`,
  `rpm`, `sudo`, `gnome-extensions`, `gnome-shell`, `fc-list`, `xdg-mime`,
  `xdg-settings` and `plymouth`;
- seeds a realistic Fedora GNOME baseline (Breeze/Adwaita themes, 24h clock,
  Fedora button layout, empty favorites/extensions);
- removes the sandbox on exit, including after a failing test.

Tests call `uf_test <name> <function>` and use assertions such as
`uf_assert_eq`, `uf_assert_contains`, `uf_assert_no_file` and
`uf_assert_fails`. There is no Bats, shellcheck or network dependency.

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

## Static checks

```bash
bash -n ubuntuify bin/ubuntuify
for file in src/*.sh src/*/*.sh tests/*.sh tests/*/*.sh; do bash -n "$file" || exit 1; done
python3 -m py_compile src/core/state.py src/core/gvariant.py \
  src/core/artwork.py src/extensions/ego_helper.py
```

If `shellcheck` is installed, run it on the Bash files. The source uses
`# shellcheck shell=bash` and targeted directives; do not silence a real
warning just to make the build green.

## Dry-run first

Every mutation path has a dry-run:

```bash
./ubuntuify install --profile full --dry-run
./ubuntuify restore --dry-run
./ubuntuify uninstall --dry-run
```

Dry-run must not create state, backups, packages, dconf writes or extension
downloads. `test_dry_run_makes_no_changes` covers the install path.

## Disposable Fedora VM workflow

Use a Fedora Workstation VM with GNOME and Wayland. Do not test destructive
rollback on your daily machine.

```text
1. Install Fedora Workstation 44+ in a VM (GNOME, Wayland).
2. Snapshot the clean VM (for example "clean-fedora").
3. Clone the repository in the VM:
     git clone <repository> ubuntuify-fedora
     cd ubuntuify-fedora
4. Run:
     ./ubuntuify doctor
     ./ubuntuify install --dry-run
     ./ubuntuify install
5. Log out and back in (or reboot).
6. Verify:
     ./ubuntuify status
     ./ubuntuify status --components
     ./ubuntuify doctor
7. Check the desktop manually:
     - Yaru GTK/icons (or documented fallback)
     - left dock, 48 px icons, applications button
     - desktop Home/Trash/volume icons
     - tray indicators
     - Super+A, Super+E, Super+L, Ctrl+Alt+T
     - window buttons and edge tiling
     - Ubuntu favorites and wallpaper
     - no critical doctor errors
8. Test a profile switch:
     ./ubuntuify profile dark
     log out/in, then ./ubuntuify profile light
9. Test rollback:
     ./ubuntuify backup
     ./ubuntuify restore
     reboot
10. Verify the original Fedora desktop and that Fedora still updates:
     sudo dnf check-upgrade
11. Test uninstall:
     ./ubuntuify uninstall
     reboot
12. Restore the clean VM snapshot if anything is left behind.
```

For the opt-in boot components, test in a separate snapshot because a broken
Plymouth/GDM configuration can make the VM unbootable:

```bash
./ubuntuify install --component plymouth
./ubuntuify install --component gdm
# reboot, inspect the boot/login screen
./ubuntuify restore --component plymouth
./ubuntuify restore --component gdm
```

## Testing older/newer GNOME

The code checks schemas and keys at runtime, so the useful test is "does it skip
cleanly?" On a release where a key is missing, expect `[SKIP]`, exit status 0
for the overall install with skipped components reported, and a clear
`doctor` line. Record the Fedora and GNOME versions in the pull request.

Do not hard-code an extension version or assume that `yaru-theme` contains the
same assets on every release.
