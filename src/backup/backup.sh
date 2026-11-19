# shellcheck shell=bash
# Backup system.
#
# A backup captures the user's desktop state before Ubuntuify changes it:
# dconf/GSettings, extensions, favorites, package list, relevant config files
# and the settings transaction log. Backups are timestamped and never
# overwritten.

# uf_backup_new_id -- generate a unique backup id.
uf_backup_new_id() {
  local base id suffix=1
  base="$(uf_now)"
  id="$base"
  while [ -e "${UF_BACKUP_ROOT}/${id}" ]; do
    suffix=$((suffix + 1))
    id="${base}-${suffix}"
  done
  printf '%s\n' "$id"
}

# uf_backup_source_files -- config paths (relative to $HOME) worth saving.
uf_backup_source_files() {
  printf '%s\n' \
    ".config/gtk-3.0" \
    ".config/gtk-4.0" \
    ".config/nautilus" \
    ".config/gnome-shell" \
    ".config/ubuntuify" \
    ".local/share/applications"
}

# uf_backup_create [REASON] -- create a backup and set UF_BACKUP_ID.
uf_backup_create() {
  local reason="${1:-manual}" id dir source existing=() failures=0

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would create a backup of the current desktop state (${reason})"
    return 0
  fi

  mkdir -p "$UF_BACKUP_ROOT"
  id="$(uf_backup_new_id)"
  dir="${UF_BACKUP_ROOT}/${id}"
  mkdir -p "$dir"

  uf_step "Creating backup ${id} (${reason})"

  {
    printf 'id=%s\n' "$id"
    printf 'reason=%s\n' "$reason"
    printf 'created=%s\n' "$(uf_datetime)"
    printf 'host=%s\n' "$(uname -n 2>/dev/null || printf unknown)"
    printf 'ubuntuify_version=%s\n' "$UF_VERSION"
    printf 'fedora_version=%s\n' "${UF_DISTRO_VERSION_ID:-unknown}"
    printf 'gnome_version=%s\n' "${UF_GNOME_VERSION:-unknown}"
    printf 'session=%s\n' "${UF_SESSION_TYPE:-unknown}"
    printf 'user=%s\n' "${USER:-unknown}"
  } >"${dir}/meta.txt"

  if uf_have dconf; then
    if dconf dump / >"${dir}/dconf.dump" 2>/dev/null; then
      uf_debug "Saved dconf database"
    else
      printf '' >"${dir}/dconf.dump"
      uf_warn "Could not dump dconf; the backup will rely on recorded settings."
      failures=$((failures + 1))
    fi
  else
    uf_warn "dconf is not installed; skipping the dconf dump."
    failures=$((failures + 1))
  fi

  if uf_have gsettings; then
    if gsettings list-recursively >"${dir}/gsettings.dump" 2>/dev/null; then
      uf_debug "Saved GSettings dump"
    else
      printf '' >"${dir}/gsettings.dump"
      uf_warn "Could not dump GSettings."
      failures=$((failures + 1))
    fi
  fi

  if uf_have gnome-extensions; then
    gnome-extensions list >"${dir}/extensions-installed.txt" 2>/dev/null || true
    gnome-extensions list --enabled >"${dir}/extensions-enabled.txt" 2>/dev/null || true
    gnome-extensions list --disabled >"${dir}/extensions-disabled.txt" 2>/dev/null || true
  else
    gsettings get org.gnome.shell enabled-extensions >"${dir}/extensions-enabled.txt" 2>/dev/null || true
  fi

  gsettings get org.gnome.shell favorite-apps >"${dir}/favorites.txt" 2>/dev/null || true
  uf_backup_write_packages "${dir}/packages-before.txt"

  if [ -f "$UF_STATE_FILE" ]; then
    cp -- "$UF_STATE_FILE" "${dir}/state.json" 2>/dev/null || true
  fi
  if [ -f "$UF_ORIGINAL_SETTINGS" ]; then
    cp -- "$UF_ORIGINAL_SETTINGS" "${dir}/original-settings.tsv" 2>/dev/null || true
  fi
  if [ -f "$UF_APPLIED_SETTINGS" ]; then
    cp -- "$UF_APPLIED_SETTINGS" "${dir}/applied-settings.tsv" 2>/dev/null || true
  fi

  while IFS= read -r source; do
    if [ -e "${HOME}/${source}" ]; then
      existing+=("$source")
    fi
  done < <(uf_backup_source_files)

  if [ "${#existing[@]}" -gt 0 ]; then
    if tar -cf "${dir}/user-config.tar" -C "$HOME" -- "${existing[@]}" 2>/dev/null; then
      uf_debug "Saved user configuration files"
    else
      uf_warn "Could not archive user configuration files."
      failures=$((failures + 1))
    fi
  fi

  if uf_have sha256sum; then
    (
      cd -- "$dir" || exit 1
      : >checksums.sha256.tmp
      for file in ./*; do
        case "$file" in
          ./checksums.sha256 | ./checksums.sha256.tmp) continue ;;
        esac
        sha256sum -- "$file" >>checksums.sha256.tmp 2>/dev/null || true
      done
      mv -f -- checksums.sha256.tmp checksums.sha256
    )
  fi

  UF_BACKUP_ID="$id"
  uf_state_set "backup" "$id"
  uf_ok "Backup created: ${id}"
  uf_debug "Backup location: ${dir}"

  if [ "$failures" -gt 0 ]; then
    uf_warn "Backup completed with ${failures} limitation(s); see ${UF_LOG_FILE:-the log}."
  fi

  uf_backup_prune
  return 0
}

# uf_backup_write_packages FILE -- snapshot installed packages.
uf_backup_write_packages() {
  local file="$1"
  if uf_have rpm; then
    rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort -u >"$file" || { : >"$file"; return 1; }
    return 0
  fi
  if uf_have dnf; then
    dnf -q list --installed 2>/dev/null | awk 'NR > 1 {print $1}' | sort -u >"$file" || true
  fi
  return 0
}

# uf_backup_list -- list backup ids, newest last.
uf_backup_list() {
  [ -d "$UF_BACKUP_ROOT" ] || return 0
  local dir
  for dir in "$UF_BACKUP_ROOT"/*/; do
    [ -d "$dir" ] || continue
    basename -- "$dir"
  done | sort
}

# uf_backup_latest -- print the newest backup id.
uf_backup_latest() {
  uf_backup_list | tail -n 1
}

# uf_backup_exists ID
uf_backup_exists() {
  local id="${1:-}"
  [ -n "$id" ] || return 1
  [[ $id =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [ -d "${UF_BACKUP_ROOT}/${id}" ]
}

# uf_backup_verify ID -- check a backup is present and internally consistent.
uf_backup_verify() {
  local id="$1" dir
  if ! uf_backup_exists "$id"; then
    uf_error "Backup not found: ${id}"
    return 1
  fi
  dir="${UF_BACKUP_ROOT}/${id}"
  if [ ! -f "${dir}/meta.txt" ]; then
    uf_error "Backup ${id} is missing its metadata."
    return 1
  fi
  if [ ! -s "${dir}/dconf.dump" ] && [ ! -s "${dir}/gsettings.dump" ] && [ ! -s "${dir}/original-settings.tsv" ]; then
    uf_warn "Backup ${id} contains no restorable desktop settings."
    return 1
  fi
  if [ -f "${dir}/checksums.sha256" ] && uf_have sha256sum; then
    if ! (cd -- "$dir" && sha256sum -c --quiet checksums.sha256 >/dev/null 2>&1); then
      uf_warn "Backup ${id} failed checksum verification."
      return 1
    fi
  fi
  return 0
}

# uf_backup_info ID -- print backup metadata.
uf_backup_info() {
  local id="$1"
  uf_backup_exists "$id" || return 1
  cat "${UF_BACKUP_ROOT}/${id}/meta.txt" 2>/dev/null
}

# uf_backup_prune -- keep the newest N backups (config backup.keep).
uf_backup_prune() {
  local keep count id
  keep="$(uf_conf_int "backup.keep" 10 1 100)"
  count=0
  local ids=()
  while IFS= read -r id; do
    ids+=("$id")
  done < <(uf_backup_list)

  local total="${#ids[@]}"
  [ "$total" -le "$keep" ] && return 0

  local to_remove=$((total - keep))
  local index=0
  while [ "$index" -lt "$to_remove" ]; do
    id="${ids[$index]}"
    if [ "$id" != "${UF_BACKUP_ID:-}" ]; then
      uf_debug "Pruning old backup ${id}"
      uf_safe_remove_tree "${UF_BACKUP_ROOT}/${id}" || true
    fi
    index=$((index + 1))
  done
  return 0
}

# uf_backup_show -- human readable backup listing for the CLI.
uf_backup_show() {
  local ids=() id reason created
  while IFS= read -r id; do
    ids+=("$id")
  done < <(uf_backup_list)
  if [ "${#ids[@]}" -eq 0 ]; then
    uf_info "No backups yet. Run 'ubuntuify backup' to create one."
    return 0
  fi
  uf_section "Backups"
  for id in "${ids[@]}"; do
    reason="$(awk -F= '$1=="reason" {print $2}' "${UF_BACKUP_ROOT}/${id}/meta.txt" 2>/dev/null || true)"
    created="$(awk -F= '$1=="created" {sub(/^created=/, ""); print}' "${UF_BACKUP_ROOT}/${id}/meta.txt" 2>/dev/null || true)"
    printf '  %-24s %-10s %s\n' "$id" "${reason:-unknown}" "${created:-}"
  done
}
