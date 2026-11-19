# Security

## Supported versions

Security fixes are applied to the latest `1.x` release. Fedora releases that
have reached end-of-life are not supported.

## Reporting a vulnerability

Please do **not** open a public issue for a vulnerability. Contact the
maintainers privately through the repository's security advisory feature or the
contact address listed in the project metadata. Include:

- affected version and Fedora/GNOME versions;
- a minimal reproduction;
- the impact (for example, privilege escalation, arbitrary code execution,
  unsafe file deletion);
- whether the issue is already public.

You will receive an acknowledgement as soon as possible. Please allow time for a
fix before disclosure.

## Privilege model

Ubuntuify runs entirely as the invoking user. It never asks to be run with
`sudo ./ubuntuify` and never re-executes itself as root. Elevated operations are
individual commands:

- `dnf install` / `dnf remove`;
- Plymouth theme files;
- GDM logo/background files.

`src/core/permissions.sh` checks for `sudo` and requires an interactive terminal
unless passwordless sudo is available. Dry-run never invokes root commands.
Plymouth and GDM are opt-in components and require explicit confirmation.

## Network access

The only non-DNF network access is the optional extensions.gnome.org fallback.
It is disabled by default, requires explicit consent and is never used by
`--yes`. The implementation:

- uses `curl --proto '=https' --tlsv1.2` with timeouts;
- validates the API response UUID and `download_url` pattern;
- validates the downloaded ZIP's `metadata.json` UUID;
- installs through `gnome-extensions install --force`;
- never pipes a download into a shell and never executes downloaded scripts.

No passwords are stored. No telemetry is collected. No arbitrary remote
configuration is fetched.

## Untrusted input handling

- Configuration is parsed as `key=value`; it is never sourced.
- `/etc/os-release` is parsed line by line, not executed.
- All shell expansions are quoted; `set -Eeuo pipefail` is used.
- `eval` is not used.
- Backup IDs are validated against `^[A-Za-z0-9._-]+$` before path use.
- Recursive removal is restricted to paths inside the Ubuntuify state root and
  refuses unresolved/empty roots.
- Extension registry fields are treated as data; the UUID and archive are
  checked before enabling/installing.
- JSON state is written atomically with mode `0600`.

## Package integrity

Fedora packages are installed through DNF and verified by RPM/GPG as configured
on the system. Ubuntuify does not disable GPG checks, does not add third-party
repositories and does not copy binaries into system paths. The project does not
redistribute Ubuntu or Yaru assets; wallpaper and the Plymouth mark are
generated locally from original geometry and the Yaru-inspired palette.

## Known limitations

- Ubuntuify changes user desktop configuration and can install GNOME Shell
  extensions; a malicious or compromised extension remains a risk outside this
  project's control.
- `sudo` behaviour depends on the system's PAM/sudoers policy.
- Backups contain dconf dumps and user configuration; they are stored with user
  permissions under `~/.local/share/ubuntuify`, but they are not encrypted.
- A compromised user account can modify Ubuntuify state and configuration, as it
  can modify any other user-level desktop setting.

## Safe defaults

- Boot branding is opt-in and never included in a profile.
- `--yes` skips the online extension fallback.
- Unknown/missing settings are skipped, not forced.
- Existing shortcut conflicts are kept by default.
- `reset` preserves settings the user changed after install.
- Uninstall keeps packages unless `--remove-packages` is explicit.
- Backups are verified before a full restore.
