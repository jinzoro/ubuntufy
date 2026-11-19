# shellcheck shell=bash
# Ubuntuify Fedora - shared library.
#
# Sourced by src/main.sh (CLI) and by the test harness. It defines the public
# globals, loads every module and never executes a command on its own, so it is
# safe to source from tests.

# shellcheck disable=SC2034
UF_NAME="Ubuntuify Fedora"
UF_SLUG="ubuntuify"
UF_DESCRIPTION="Transform Fedora GNOME into an Ubuntu-like desktop experience while keeping Fedora underneath."
UF_VERSION="1.0.0"
UF_STATE_SCHEMA_VERSION=1

: "${HOME:?HOME must be set}"

if [ -z "${UF_ROOT:-}" ]; then
  UF_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
fi
export UF_ROOT

# XDG locations. Everything Ubuntuify writes lives below these paths.
UF_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
UF_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
UF_STATE_HOME="${UF_DATA_HOME}/ubuntuify"
UF_STATE_DIR="${UF_STATE_HOME}/state"
UF_BACKUP_ROOT="${UF_STATE_HOME}/backups"
UF_LOG_DIR="${UF_STATE_HOME}/logs"
UF_CACHE_DIR="${UF_STATE_HOME}/cache"
UF_WALLPAPER_DIR="${UF_STATE_HOME}/wallpapers"
UF_USER_CONFIG="${UF_CONFIG_HOME}/ubuntuify/config.conf"
UF_STATE_FILE="${UF_STATE_DIR}/state.json"
UF_ORIGINAL_SETTINGS="${UF_STATE_DIR}/original-settings.tsv"
UF_APPLIED_SETTINGS="${UF_STATE_DIR}/applied-settings.tsv"
UF_BACKUP_INDEX="${UF_STATE_DIR}/backups.tsv"
UF_LOCK_FILE="${UF_STATE_HOME}/.lock"

# Runtime flags. Tests and the CLI may override these before calling the API.
UF_DRY_RUN="${UF_DRY_RUN:-0}"
UF_ASSUME_YES="${UF_ASSUME_YES:-0}"
UF_VERBOSE="${UF_VERBOSE:-0}"
UF_QUIET="${UF_QUIET:-0}"
UF_NO_COLOR="${UF_NO_COLOR:-0}"
UF_ONLINE_EXTENSIONS="${UF_ONLINE_EXTENSIONS:-ask}"
UF_NO_BACKUP="${UF_NO_BACKUP:-0}"
UF_FORCE_BACKUP="${UF_FORCE_BACKUP:-0}"
UF_REMOVE_PACKAGES="${UF_REMOVE_PACKAGES:-0}"
UF_ALLOW_UNSUPPORTED="${UF_ALLOW_UNSUPPORTED:-0}"
UF_OS_RELEASE_FILE="${UF_OS_RELEASE_FILE:-/etc/os-release}"

# Current component context (used by the settings transaction log).
UF_CURRENT_COMPONENT="${UF_CURRENT_COMPONENT:-manual}"
UF_CURRENT_PHASE="${UF_CURRENT_PHASE:-}"

# Bookkeeping shared between modules.
UF_WARN_COUNT="${UF_WARN_COUNT:-0}"
UF_ERROR_COUNT="${UF_ERROR_COUNT:-0}"
UF_SKIP_COUNT="${UF_SKIP_COUNT:-0}"
UF_CHANGED_COUNT="${UF_CHANGED_COUNT:-0}"
UF_BACKUP_ID="${UF_BACKUP_ID:-}"

# CLI selections consumed by the engine.
UF_OPT_PROFILE="${UF_OPT_PROFILE:-}"
UF_OPT_COMPONENTS=()
UF_OPT_BACKUP="${UF_OPT_BACKUP:-}"
UF_OPT_COMPONENT="${UF_OPT_COMPONENT:-}"

# Resolve module directory (works when the library is sourced via a symlink).
UF_SRC="${UF_ROOT}/src"

# shellcheck source=core/utils.sh
source "${UF_SRC}/core/utils.sh"
# shellcheck source=core/logging.sh
source "${UF_SRC}/core/logging.sh"
# shellcheck source=core/errors.sh
source "${UF_SRC}/core/errors.sh"
# shellcheck source=core/permissions.sh
source "${UF_SRC}/core/permissions.sh"
# shellcheck source=core/detection.sh
source "${UF_SRC}/core/detection.sh"
# shellcheck source=core/gsettings.sh
source "${UF_SRC}/core/gsettings.sh"
# shellcheck source=core/state.sh
source "${UF_SRC}/core/state.sh"
# shellcheck source=config.sh
source "${UF_SRC}/config.sh"
# shellcheck source=packages/detect.sh
source "${UF_SRC}/packages/detect.sh"
# shellcheck source=packages/install.sh
source "${UF_SRC}/packages/install.sh"
# shellcheck source=packages/remove.sh
source "${UF_SRC}/packages/remove.sh"
# shellcheck source=backup/backup.sh
source "${UF_SRC}/backup/backup.sh"
# shellcheck source=backup/restore.sh
source "${UF_SRC}/backup/restore.sh"
# shellcheck source=extensions/manager.sh
source "${UF_SRC}/extensions/manager.sh"
# shellcheck source=extensions/tiling.sh
source "${UF_SRC}/extensions/tiling.sh"
# shellcheck source=theme/yaru.sh
source "${UF_SRC}/theme/yaru.sh"
# shellcheck source=theme/icons.sh
source "${UF_SRC}/theme/icons.sh"
# shellcheck source=theme/cursor.sh
source "${UF_SRC}/theme/cursor.sh"
# shellcheck source=theme/fonts.sh
source "${UF_SRC}/theme/fonts.sh"
# shellcheck source=gnome/appearance.sh
source "${UF_SRC}/gnome/appearance.sh"
# shellcheck source=gnome/panel.sh
source "${UF_SRC}/gnome/panel.sh"
# shellcheck source=gnome/overview.sh
source "${UF_SRC}/gnome/overview.sh"
# shellcheck source=gnome/shortcuts.sh
source "${UF_SRC}/gnome/shortcuts.sh"
# shellcheck source=gnome/windows.sh
source "${UF_SRC}/gnome/windows.sh"
# shellcheck source=gnome/workspaces.sh
source "${UF_SRC}/gnome/workspaces.sh"
# shellcheck source=gnome/notifications.sh
source "${UF_SRC}/gnome/notifications.sh"
# shellcheck source=gnome/power.sh
source "${UF_SRC}/gnome/power.sh"
# shellcheck source=applications/nautilus.sh
source "${UF_SRC}/applications/nautilus.sh"
# shellcheck source=applications/defaults.sh
source "${UF_SRC}/applications/defaults.sh"
# shellcheck source=applications/favorites.sh
source "${UF_SRC}/applications/favorites.sh"
# shellcheck source=desktop/dock.sh
source "${UF_SRC}/desktop/dock.sh"
# shellcheck source=desktop/icons.sh
source "${UF_SRC}/desktop/icons.sh"
# shellcheck source=desktop/wallpaper.sh
source "${UF_SRC}/desktop/wallpaper.sh"
# shellcheck source=desktop/tray.sh
source "${UF_SRC}/desktop/tray.sh"
# shellcheck source=desktop/sound.sh
source "${UF_SRC}/desktop/sound.sh"
# shellcheck source=boot/plymouth.sh
source "${UF_SRC}/boot/plymouth.sh"
# shellcheck source=boot/gdm.sh
source "${UF_SRC}/boot/gdm.sh"
# shellcheck source=diagnostics/doctor.sh
source "${UF_SRC}/diagnostics/doctor.sh"
# shellcheck source=diagnostics/status.sh
source "${UF_SRC}/diagnostics/status.sh"
# shellcheck source=components.sh
source "${UF_SRC}/components.sh"
# shellcheck source=engine.sh
source "${UF_SRC}/engine.sh"
# shellcheck source=cli.sh
source "${UF_SRC}/cli.sh"
