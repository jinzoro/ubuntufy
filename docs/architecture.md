# Architecture

Ubuntuify Fedora is a Bash application with three small Python standard-library
helpers. It deliberately avoids frameworks: every operation is auditable in a
text editor, and the only runtime dependencies are tools already present on a
Fedora Workstation GNOME system.

## Goals that shape the design

1. **Preserve Fedora.** Never replace repositories, `/etc/os-release`, DNF,
   RPM, the kernel or systemd. Ubuntuify is a user-level configuration layer
   plus optional Fedora packages.
2. **Reversible.** Every change must be restorable, including partial installs
   and interrupted runs.
3. **Modular.** A component can be applied, skipped or restored independently.
4. **Version-adaptive.** Never hard-code GNOME Shell extension versions or
   assume that an optional schema/key exists. Detect and degrade gracefully.
5. **Non-interactive safe.** `--yes` must never silently download an extension
   or touch boot branding.

## Execution flow

```text
ubuntuify / bin/ubuntuify
        │
        └── src/main.sh            sets UF_ROOT, traps, lock release
              └── src/cli.sh       parses flags/commands, help, interactive menu
                    └── src/engine.sh
                          ├── uf_runtime_init   dirs, log, lock, config, detect
                          ├── uf_require_*      Fedora / GNOME / tools
                          ├── uf_install        backup, state, components
                          ├── uf_uninstall      restore, extension cleanup
                          ├── uf_restore_*      full or per-component rollback
                          ├── uf_update         re-apply recorded profile
                          └── uf_reset          forget managed settings safely
                                └── src/components.sh
                                      └── component functions
```

Component functions live in focused modules (`src/theme`, `src/gnome`,
`src/desktop`, `src/applications`, `src/boot`). `src/components.sh` is the only
place that knows the component registry, apply order, aliases and profile
expansion.

## Module responsibilities

| Path | Responsibility |
| --- | --- |
| `src/lib.sh` | Constants, XDG paths, runtime flags, module loading only. |
| `src/main.sh` | Entry point, root detection, ERR/INT/TERM traps, lock release. |
| `src/cli.sh` | Argument parsing, command dispatch, help text, interactive menu. |
| `src/engine.sh` | Install/uninstall/restore/update/reset workflows and locking. |
| `src/components.sh` | Registry, titles, aliases, order, profile expansion. |
| `src/config.sh` | Defaults → user config → CLI precedence, validation, persistence. |
| `src/core/detection.sh` | os-release, GNOME, session, tools, GSettings runtime. |
| `src/core/gsettings.sh` | Safe `gsettings` wrapper, schema/key/range checks, transaction log. |
| `src/core/state.sh` | Thin wrapper around `state.py`. |
| `src/core/state.py` | Atomic JSON state updates. |
| `src/core/logging.sh` | `[INFO]/[OK]/[WARN]/[ERROR]/[SKIP]`, timestamps, color, log file. |
| `src/core/errors.sh` | Preconditions and fatal error handling. |
| `src/core/permissions.sh` | User/root separation, `sudo` checks. |
| `src/core/utils.sh` | Strings, lists, booleans, integer validation, path guards. |
| `src/packages/*` | DNF/RPM queries, install/removal, package ownership tracking. |
| `src/backup/*` | Snapshot creation, verification and restore. |
| `src/extensions/*` | RPM-first extension management, EGO fallback, tiling. |
| `src/theme/*` | Yaru GTK/icons/cursor/fonts and fallbacks. |
| `src/gnome/*` | Panel, overview, shortcuts, windows, workspaces, notifications, power. |
| `src/desktop/*` | Dock, desktop icons, tray, wallpaper, sound. |
| `src/applications/*` | Favorites, Nautilus and default applications. |
| `src/boot/*` | Opt-in Plymouth and GDM branding with explicit confirmation. |
| `src/diagnostics/*` | `doctor` and `status` reporting. |

## GSettings safety layer

`src/core/gsettings.sh` is the only code allowed to call `gsettings set`.

For every setting it:

1. checks that the schema exists (`gsettings list-schemas`, cached);
2. checks that the key exists in that schema (cached);
3. validates enum/integer/boolean range when the schema exposes one;
4. reads the current value and skips if it already matches (idempotency);
5. records the original value once in `original-settings.tsv`;
6. records the applied value in `applied-settings.tsv`;
7. in dry-run mode, prints the intended change and writes nothing.

Missing optional schemas/keys become `[SKIP]` lines, not fatal errors. This is
why Ubuntuify can run on an older or newer GNOME release without pretending
that every key exists.

Shortcuts are written through the same layer. A shortcut that is already bound
to a different action is detected and, depending on
`shortcuts.on_conflict`, kept, replaced or prompted for.

## State model

All state is under `${XDG_DATA_HOME:-~/.local/share}/ubuntuify/`:

```text
ubuntuify/
├── .lock                       flock target
├── state/
│   ├── state.json              profile, versions, packages, components, wallpaper
│   ├── original-settings.tsv   component<TAB>schema<TAB>key<TAB>original value
│   ├── applied-settings.tsv    component<TAB>schema<TAB>key<TAB>applied value
│   └── backups.tsv             backup ID/index
├── backups/
│   └── 2026-11-19-171500/      dconf dump, originals, state, package and extension lists
├── cache/                      ephemeral downloads (removed after use)
├── wallpapers/                 locally generated artwork
└── logs/                       one timestamped log per operation
```

`state.json` is only written by `src/core/state.py`; Bash never concatenates
JSON. Updates are atomic: write to a temporary file, `chmod 600`, `os.replace`.

`original-settings.tsv` and `applied-settings.tsv` are the source of truth for
component restore. A setting is recorded as the original only the first time
Ubuntuify changes it, so later profile switches cannot overwrite the true
pre-install value. `reset` compares the current value with the applied value and
preserves settings the user changed afterwards.

Backups are timestamped and never overwritten. `uf_backup_create` stores:

- a `dconf dump /` snapshot;
- the original settings log (when present);
- `state.json` and profile metadata;
- package and enabled-extension lists;
- a checksum manifest.

## Configuration precedence

Highest priority first:

1. command-line flags;
2. `~/.config/ubuntuify/config.conf`;
3. `config/ubuntu-defaults.conf`;
4. built-in fallbacks.

The user config is parsed as `key=value` with quotes stripped and `#` comments
ignored. It is never sourced, so it cannot execute code. Invalid integers fall
back to their documented defaults with a warning, unknown keys are ignored,
and booleans accept `true/false/1/0/yes/no/on/off`.

## Privilege model

Ubuntuify runs entirely as the invoking user. Only these operations use
`sudo`, one command at a time:

- `dnf install` / `dnf remove`;
- Plymouth theme installation;
- GDM logo/background installation.

Package operations check whether the user can use `sudo` before starting. The
application never asks for or stores a password and never runs itself as root.
Opt-in boot components call `uf_confirm_root_action` and always create backups
first.

## Extension policy

`config/extensions.conf` maps a logical extension name (for example
`appindicator`) to candidate UUIDs, Fedora packages, EGO slugs and settings.
Resolution order:

1. An already-installed UUID;
2. a Fedora RPM;
3. the official extensions.gnome.org API, only with explicit consent;
4. skip with a warning.

Shell-version compatibility is checked before enabling. For the EGO fallback,
the API response and ZIP metadata are validated with `ego_helper.py`; the
download is HTTPS-only and is never piped into a shell. `--yes` disables the
EGO path even if the configuration says `ask`.

## Why Bash and Python

Bash is the right tool for DNF, GSettings, dconf, file operations and process
control, and it keeps the system-facing code short and inspectable. Python is
used only where Bash would be fragile:

- `state.py` for atomic JSON;
- `gvariant.py` for parsing and writing GVariant arrays (favorites, shortcuts);
- `ego_helper.py` for validating extension metadata and archives.

`artwork.py` generates the original wallpaper and Plymouth logo using only
`zlib`/`struct`; it is an optional helper, not a runtime dependency beyond
Python 3.

## Failure handling

- `set -Eeuo pipefail` is active in launchers and modules.
- ERR prints the failing command and line and points at the log.
- Component failures are counted and reported; a failed optional component does
  not silently mark the install successful.
- The lock prevents two apply operations from interleaving.
- The state path guard refuses recursive removal when the state root cannot be
  resolved (for example an empty `XDG_DATA_HOME`).
- Dry-run never creates state, backups, packages or settings.

## Deliberate limitations

There is no attempt to reproduce Ubuntu's downstream GNOME patches, APT
behaviour, Snap integration, Ubuntu kernel or Ubuntu-specific system services.
Those are distribution-level differences and cannot be recreated safely from a
user-space configuration tool. See [Compatibility and limitations](../README.md#compatibility)
and [troubleshooting](troubleshooting.md).
