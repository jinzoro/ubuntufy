# GNOME extensions

Ubuntuify's Ubuntu-like behaviour depends on a small set of GNOME Shell
extensions. Fedora packages are used whenever possible. The project never
assumes a fixed extension version: it resolves the installed UUID, checks
compatibility and skips rather than enabling something that declares no support
for the running GNOME Shell.

## Registry

`config/extensions.conf` is the single source of truth:

```text
extension|name|label|fedora-packages|uuids|ego-id|required
conflict|target|label|uuid|fedora-package
```

- `fedora-packages` and `uuids` are `;`-separated alternatives, most preferred
  first. This is why both the Fedora and Ubuntu UUIDs can be listed for
  AppIndicator and Dash to Dock.
- `ego-id` is the numeric extensions.gnome.org ID used only when Fedora does
  not provide the extension.
- `required` documents the intent; unavailable required extensions are reported
  by `doctor` and skipped with a warning, because forcing an incompatible
  extension would break the shell.

Current entries:

| Component | Fedora package | UUID(s) | EGO ID |
| --- | --- | --- | --- |
| Tray | `gnome-shell-extension-appindicator` | `appindicatorsupport@rgcjonas.gmail.com`, `ubuntu-appindicators@ubuntu.com` | 615 |
| Desktop icons | `gnome-shell-extension-desktop-icons-ng`, `gnome-shell-extension-ding` | `ding@rastersoft.com` | 2087 |
| Dock | `gnome-shell-extension-dash-to-dock` | `dash-to-dock@micxgx.gmail.com`, `ubuntu-dock@ubuntu.com` | 307 |
| Tiling | `gnome-shell-extension-tiling-assistant` | `tiling-assistant@leleat-on-github` | 3739 |
| User Themes | `gnome-shell-extension-user-theme` | `user-theme@gnome-shell-extensions.gcampax.github.com` | 19 |

Conflicts are detected for Dash to Panel and ArcMenu (dock), legacy Desktop
Icons (desktop icons), and gTile (tiling). In automated mode the conflicting
extension is kept and the component is skipped; interactively the user can
choose to disable the conflict or skip the component.

## Resolution order

```text
already installed UUID
        ↓ no
Fedora RPM (dnf install)
        ↓ unavailable
extensions.gnome.org (explicit consent, never with --yes)
        ↓ declined/unavailable
skip with a warning
```

After installation, the manager:

1. resolves the actual UUID from the registry candidates;
2. reads `metadata.json` and compares `shell-version` with the running GNOME
   major version;
3. refuses to enable an extension that explicitly declares no support;
4. enables it through `gnome-extensions` and also writes the durable
   `org.gnome.shell enabled-extensions` array (session-independent);
5. records it in state as managed by Ubuntuify.

If `gnome-extensions enable` cannot take effect in the current session, the
extension is still enabled in GSettings and the message says it will apply after
the next login.

## extensions.gnome.org fallback

The fallback is deliberately conservative:

- `--online-extensions` or `online_extensions=yes` is required, or the user must
  answer yes to an explicit prompt;
- `--yes` never uses the fallback, even if the config says `ask`;
- the API call is HTTPS-only with `curl --proto '=https' --tlsv1.2` and a
  timeout;
- the API response is validated to be the requested UUID and a
  `/download-extension/...shell-extension.zip` path;
- the ZIP is downloaded to the cache, its `metadata.json` UUID is checked, and
  installation uses `gnome-extensions install --force`;
- nothing is piped into a shell and no downloaded script is executed.

If `curl` or `gnome-extensions` is missing, the component is skipped with a
message.

## Known Fedora gaps

Availability changes between Fedora releases. At the time of development on
Fedora 45:

- `yaru-theme` is available, providing GTK, icon, sound and (on some releases)
  shell assets;
- AppIndicator, Dash to Dock, Tiling Assistant and User Themes have Fedora RPMs;
- Desktop Icons NG is not packaged, so it requires the EGO fallback or manual
  installation;
- Ubuntu fonts and the Yaru cursor theme are not packaged by Fedora.

Ubuntuify never fabricates these packages or copies assets from Ubuntu. The
affected component reports `[SKIP]` or `[WARN]`, and `doctor` explains the gap.
See the compatibility notes in [README.md](../README.md#compatibility).

## Checking extension health

```bash
ubuntuify doctor
ubuntuify status --components
gnome-extensions list
gnome-extensions info <uuid>
gsettings get org.gnome.shell enabled-extensions
```

If an extension is installed but disabled, log out and back in after
`ubuntuify install`, or enable it explicitly:

```bash
gnome-extensions enable dash-to-dock@micxgx.gmail.com
```

## Adding an extension

1. Add an `extension|...` row with Fedora package, candidate UUIDs and EGO ID.
2. Add any known conflicting extensions as `conflict|...` rows.
3. Use it through `uf_ext_component_guard <name>` in the component function.
4. Add a mock package entry and a unit test if the resolution logic changes.
5. Verify on a Fedora GNOME VM that the extension is available for the current
   release, or that the component degrades cleanly.
