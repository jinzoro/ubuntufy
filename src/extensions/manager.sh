# shellcheck shell=bash
# GNOME extension manager.
#
# Extensions are installed from Fedora packages first. Only when Fedora does
# not package an extension, and only with explicit consent, the official
# extensions.gnome.org service is used. Compatibility is checked against the
# running GNOME Shell major version; incompatible extensions are never
# enabled.

UF_EXT_GV="${UF_SRC}/core/gvariant.py"
UF_EXT_EGO_HELPER="${UF_SRC}/extensions/ego_helper.py"

declare -gA UF_EXT_LABEL=()
declare -gA UF_EXT_PKGS=()
declare -gA UF_EXT_UUIDS=()
declare -gA UF_EXT_EGO=()
declare -gA UF_EXT_REQUIRED=()
declare -ga UF_EXT_NAMES=()
declare -ga UF_EXT_CONFLICT_ROWS=()
UF_EXT_REGISTRY_LOADED="${UF_EXT_REGISTRY_LOADED:-0}"
UF_EXT_INSTALLED_CACHE="${UF_EXT_INSTALLED_CACHE:-__unset__}"

# uf_ext_load_registry -- parse config/extensions.conf once.
uf_ext_load_registry() {
  [ "${UF_EXT_REGISTRY_LOADED:-0}" -eq 1 ] && return 0
  UF_EXT_REGISTRY_LOADED=1
  local file="${UF_ROOT}/config/extensions.conf" line kind a b c d e f
  [ -r "$file" ] || {
    uf_error "Extension registry missing: ${file}"
    return 1
  }
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(uf_trim "$line")"
    case "$line" in
      '' | \#*) continue ;;
    esac
    IFS='|' read -r kind a b c d e f <<<"$line"
    case "$kind" in
      extension)
        UF_EXT_NAMES+=("$a")
        UF_EXT_LABEL["$a"]="$b"
        UF_EXT_PKGS["$a"]="$c"
        UF_EXT_UUIDS["$a"]="$d"
        UF_EXT_EGO["$a"]="$e"
        UF_EXT_REQUIRED["$a"]="$f"
        ;;
      conflict)
        UF_EXT_CONFLICT_ROWS+=("$a|$b|$c|$d")
        ;;
      *)
        uf_warn "Ignoring unknown extension registry entry: ${line}"
        ;;
    esac
  done <"$file"
  return 0
}

# uf_ext_installed_uuids -- one installed extension uuid per line.
uf_ext_installed_uuids() {
  if [ "$UF_EXT_INSTALLED_CACHE" != "__unset__" ]; then
    printf '%s' "$UF_EXT_INSTALLED_CACHE"
    return 0
  fi
  local list="" dir uuid base
  if uf_have gnome-extensions; then
    list="$(gnome-extensions list 2>/dev/null || true)"
  fi
  if [ -z "$list" ]; then
    for base in "${HOME}/.local/share/gnome-shell/extensions" "/usr/share/gnome-shell/extensions"; do
      [ -d "$base" ] || continue
      for dir in "$base"/*/; do
        [ -d "$dir" ] || continue
        uuid="$(basename -- "$dir")"
        list+="${uuid}"$'\n'
      done
    done
    local enabled
    enabled="$(uf_gs_get org.gnome.shell enabled-extensions 2>/dev/null || true)"
    if [ -n "$enabled" ]; then
      local item
      while IFS= read -r item; do
        [ -n "$item" ] && list+="${item}"$'\n'
      done < <(python3 "$UF_EXT_GV" list-get "$enabled" 2>/dev/null || true)
    fi
  fi
  UF_EXT_INSTALLED_CACHE="$(printf '%s\n' "$list" | sed '/^$/d' | sort -u)"
  printf '%s' "$UF_EXT_INSTALLED_CACHE"
}

# uf_ext_cache_clear -- invalidate cached extension lists.
uf_ext_cache_clear() {
  UF_EXT_INSTALLED_CACHE="__unset__"
}

# uf_ext_uuid_installed UUID
uf_ext_uuid_installed() {
  local uuid="$1" item
  while IFS= read -r item; do
    [ "$item" = "$uuid" ] && return 0
  done < <(uf_ext_installed_uuids)
  return 1
}

# uf_ext_resolve NAME -- print the installed uuid for a registry name.
uf_ext_resolve() {
  local name="$1" uuid
  uf_ext_load_registry || return 1
  while IFS= read -r uuid; do
    if uf_ext_uuid_installed "$uuid"; then
      printf '%s\n' "$uuid"
      return 0
    fi
  done < <(uf_split_list ';' "${UF_EXT_UUIDS[$name]:-}")
  return 1
}

# uf_ext_enabled_array_has UUID
uf_ext_enabled_array_has() {
  local uuid="$1" raw
  raw="$(uf_gs_get org.gnome.shell enabled-extensions 2>/dev/null || true)"
  python3 "$UF_EXT_GV" list-has "$raw" "$uuid" >/dev/null 2>&1
}

# uf_ext_disabled_array_has UUID
uf_ext_disabled_array_has() {
  local uuid="$1" raw
  raw="$(uf_gs_get org.gnome.shell disabled-extensions 2>/dev/null || true)"
  python3 "$UF_EXT_GV" list-has "$raw" "$uuid" >/dev/null 2>&1
}

# uf_ext_is_enabled UUID
uf_ext_is_enabled() {
  local uuid="$1" enabled_list
  if uf_have gnome-extensions; then
    enabled_list="$(gnome-extensions list --enabled 2>/dev/null || true)"
    if grep -qx -- "$uuid" <<<"$enabled_list"; then
      return 0
    fi
  fi
  uf_ext_enabled_array_has "$uuid" && return 0
  if uf_ext_disabled_array_has "$uuid"; then
    return 1
  fi
  return 1
}

# uf_ext_shell_array_add UUID -- durable enablement via GSettings.
uf_ext_shell_array_add() {
  local uuid="$1" raw updated
  raw="$(uf_gs_get org.gnome.shell enabled-extensions 2>/dev/null || printf '[]')"
  updated="$(python3 "$UF_EXT_GV" list-add "$raw" "$uuid" 2>/dev/null)" || return 1
  uf_gs_set org.gnome.shell enabled-extensions "$updated" "Enabled extension ${uuid}"
}

# uf_ext_shell_array_remove UUID
uf_ext_shell_array_remove() {
  local uuid="$1" raw updated
  raw="$(uf_gs_get org.gnome.shell enabled-extensions 2>/dev/null || printf '[]')"
  updated="$(python3 "$UF_EXT_GV" list-remove "$raw" "$uuid" 2>/dev/null)" || return 1
  uf_gs_set org.gnome.shell enabled-extensions "$updated" "Disabled extension ${uuid}"
}

# uf_ext_shell_disabled_add UUID
uf_ext_shell_disabled_add() {
  local uuid="$1" raw updated
  raw="$(uf_gs_get org.gnome.shell disabled-extensions 2>/dev/null || printf '[]')"
  updated="$(python3 "$UF_EXT_GV" list-add "$raw" "$uuid" 2>/dev/null)" || return 1
  uf_gs_set org.gnome.shell disabled-extensions "$updated" "Disabled extension ${uuid}"
}

# uf_ext_shell_disabled_remove UUID
uf_ext_shell_disabled_remove() {
  local uuid="$1" raw updated
  raw="$(uf_gs_get org.gnome.shell disabled-extensions 2>/dev/null || printf '[]')"
  updated="$(python3 "$UF_EXT_GV" list-remove "$raw" "$uuid" 2>/dev/null)" || return 1
  uf_gs_set org.gnome.shell disabled-extensions "$updated" "Enabled extension ${uuid}"
}

# uf_ext_enable UUID [LABEL]
uf_ext_enable() {
  local uuid="$1" label="${2:-$uuid}" cli_ok=0 pending=0
  if uf_ext_is_enabled "$uuid"; then
    uf_ok "${label} already enabled"
    uf_state_add "enabled_extensions" "$uuid"
    return 0
  fi
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would enable extension: ${label} (${uuid})"
    return 0
  fi
  if uf_have gnome-extensions; then
    if gnome-extensions enable "$uuid" >/dev/null 2>&1; then
      cli_ok=1
    else
      pending=1
    fi
  else
    pending=1
  fi
  uf_ext_shell_array_remove "$uuid" || true
  uf_ext_shell_disabled_remove "$uuid" || true
  uf_ext_shell_array_add "$uuid" || true
  uf_state_add "enabled_extensions" "$uuid"
  if [ "$cli_ok" -eq 1 ]; then
    uf_ok "Enabled ${label} (${uuid})"
  elif [ "$pending" -eq 1 ]; then
    uf_ok "Enabled ${label} (${uuid}); it takes effect after the next login"
  fi
  return 0
}

# uf_ext_disable UUID [LABEL]
uf_ext_disable() {
  local uuid="$1" label="${2:-$uuid}"
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would disable extension: ${label} (${uuid})"
    return 0
  fi
  if uf_have gnome-extensions; then
    gnome-extensions disable "$uuid" >/dev/null 2>&1 || true
  fi
  uf_ext_shell_array_remove "$uuid" || true
  uf_ext_shell_disabled_add "$uuid" || true
  uf_ok "Disabled ${label} (${uuid})"
}

# uf_ext_metadata_file UUID -- print the metadata.json path, if any.
uf_ext_metadata_file() {
  local uuid="$1" base
  for base in "${HOME}/.local/share/gnome-shell/extensions" "/usr/share/gnome-shell/extensions"; do
    if [ -f "${base}/${uuid}/metadata.json" ]; then
      printf '%s\n' "${base}/${uuid}/metadata.json"
      return 0
    fi
  done
  return 1
}

# uf_ext_compatible UUID -- yes/no/unknown compatibility result.
uf_ext_compatible() {
  local uuid="$1" metadata result
  if [ -z "${UF_GNOME_MAJOR:-}" ]; then
    printf 'unknown\n'
    return 0
  fi
  if ! metadata="$(uf_ext_metadata_file "$uuid")"; then
    printf 'unknown\n'
    return 0
  fi
  if result="$(python3 "$UF_EXT_EGO_HELPER" shell-compatible "$metadata" "$UF_GNOME_MAJOR" 2>/dev/null)"; then
    printf '%s\n' "$result"
  else
    printf 'unknown\n'
  fi
}

# uf_ext_online_allowed LABEL -- decide whether downloading from EGO is ok.
uf_ext_online_allowed() {
  local label="$1" mode="${UF_ONLINE_EXTENSIONS:-ask}"
  if [ "$mode" = "ask" ]; then
    mode="$(uf_conf online_extensions ask)"
  fi
  case "$mode" in
    yes | true) return 0 ;;
    no | false) return 1 ;;
  esac
  if uf_is_true "$UF_ASSUME_YES"; then
    uf_info "${label} is not packaged by Fedora; skipping the online fallback in automated mode."
    return 1
  fi
  uf_confirm "${label} is not packaged by Fedora. Download it from the official extensions.gnome.org?" n
}

# uf_ext_install_from_ego NAME -- install the extension from the official
# GNOME extension service after validating URL, metadata and archive.
uf_ext_install_from_ego() {
  local name="$1" uuid ego label json_file zip_file api url path
  uf_ext_load_registry || return 1
  uuid="$(uf_split_list ';' "${UF_EXT_UUIDS[$name]:-}" | head -n 1)"
  ego="${UF_EXT_EGO[$name]:-}"
  label="${UF_EXT_LABEL[$name]:-${name}}"

  if [ -z "$uuid" ] || [ -z "$ego" ]; then
    uf_warn "No official installation source is registered for ${label}."
    return 1
  fi
  if ! uf_have curl; then
    uf_warn "curl is required to install ${label} from extensions.gnome.org."
    return 1
  fi
  if ! uf_have gnome-extensions; then
    uf_warn "gnome-extensions is required to install ${label}."
    return 1
  fi

  if [ -z "${UF_GNOME_MAJOR:-}" ]; then
    uf_warn "GNOME Shell version is unknown; refusing to download ${label}."
    return 1
  fi

  mkdir -p "$UF_CACHE_DIR"
  json_file="${UF_CACHE_DIR}/ego-${uuid}.json"
  zip_file="${UF_CACHE_DIR}/${uuid}.shell-extension.zip"
  api="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${UF_GNOME_MAJOR}"

  uf_step "Querying extensions.gnome.org for ${label}"
  if ! curl -fsSL --proto '=https' --tlsv1.2 --max-time 30 -o "$json_file" "$api" 2>/dev/null; then
    uf_warn "Could not reach extensions.gnome.org for ${label}."
    return 1
  fi
  if ! path="$(python3 "$UF_EXT_EGO_HELPER" download-path "$json_file" "$uuid" 2>/dev/null)"; then
    uf_warn "Official metadata for ${label} is missing or incompatible with GNOME ${UF_GNOME_MAJOR}."
    return 1
  fi

  url="https://extensions.gnome.org${path}"
  uf_step "Downloading ${label}"
  if ! curl -fsSL --proto '=https' --tlsv1.2 --max-time 60 -o "$zip_file" "$url" 2>/dev/null; then
    uf_warn "Could not download ${label}."
    return 1
  fi
  if ! python3 "$UF_EXT_EGO_HELPER" verify-zip "$zip_file" "$uuid" >/dev/null 2>&1; then
    uf_warn "Downloaded archive for ${label} failed validation; refusing to install it."
    rm -f -- "$zip_file"
    return 1
  fi
  if ! gnome-extensions install --force "$zip_file" >/dev/null 2>&1; then
    uf_warn "Could not install the downloaded ${label} archive."
    return 1
  fi
  uf_ext_cache_clear
  uf_ok "Installed ${label} from extensions.gnome.org (${uuid})"
  return 0
}

# uf_ext_ensure NAME -- install if missing, check compatibility, enable.
# 0 = enabled, 2 = skipped/optional problem, 1 = failure.
uf_ext_ensure() {
  local name="$1" label uuid rc=0 was_enabled=0
  uf_ext_load_registry || return 1
  label="${UF_EXT_LABEL[$name]:-}"
  if [ -z "$label" ]; then
    uf_error "Unknown extension name: ${name}"
    return 1
  fi

  if uuid="$(uf_ext_resolve "$name")"; then
    uf_ok "${label} already installed (${uuid})"
    uf_ext_is_enabled "$uuid" && was_enabled=1
    if [ "$UF_DRY_RUN" -eq 1 ]; then
      uf_dry "Would enable ${label} (${uuid})"
      return 0
    fi
  else
    uf_step "Installing ${label}"
    uf_pkg_install_first "${UF_EXT_PKGS[$name]:-}" "$label" || rc=$?
    if [ "$rc" -eq 1 ]; then
      uf_warn "Installation of ${label} failed."
      return 1
    fi
    if [ "$UF_DRY_RUN" -eq 1 ]; then
      uf_dry "Would enable ${label} after installation"
      return 0
    fi
    if [ -z "${UF_PKG_CHOSEN:-}" ]; then
      if uf_ext_online_allowed "$label"; then
        uf_ext_install_from_ego "$name" || return 1
      else
        uf_warn "${label} is unavailable and was not downloaded; skipping."
        return 2
      fi
    fi
    uuid="$(uf_ext_resolve "$name" || true)"
    if [ -z "$uuid" ]; then
      uf_warn "${label} was installed but its extension UUID was not found; skipping."
      return 1
    fi
  fi

  local compatibility
  compatibility="$(uf_ext_compatible "$uuid")"
  case "$compatibility" in
    no)
      uf_warn "${label} (${uuid}) does not declare support for GNOME ${UF_GNOME_MAJOR}; it was not enabled."
      return 2
      ;;
    unknown)
      uf_debug "Compatibility of ${uuid} could not be verified; proceeding."
      ;;
  esac

  uf_ext_enable "$uuid" "$label" || return 1
  # Only claim ownership of extensions Ubuntuify actually enabled. A user's
  # already-enabled extension must stay enabled after uninstall.
  [ "$was_enabled" -eq 1 ] || uf_state_add "managed_extensions" "$uuid"
  return 0
}

# uf_ext_check_conflicts TARGET -- print "uuid|label" for installed conflicts.
uf_ext_check_conflicts() {
  local target="$1" row conflict_target label uuid package
  uf_ext_load_registry || return 0
  for row in "${UF_EXT_CONFLICT_ROWS[@]}"; do
    IFS='|' read -r conflict_target label uuid package <<<"$row"
    [ "$conflict_target" = "$target" ] || continue
    if uf_ext_uuid_installed "$uuid"; then
      printf '%s|%s\n' "$uuid" "$label"
    fi
  done
}

# uf_ext_resolve_conflicts TARGET -- ask how to handle conflicts.
# 0 = okay to continue, 2 = skip the component.
uf_ext_resolve_conflicts() {
  local target="$1" rows row uuid label
  rows="$(uf_ext_check_conflicts "$target")"
  [ -n "$rows" ] || return 0

  while IFS='|' read -r uuid label; do
    [ -n "$uuid" ] || continue
    uf_warn "Potential conflict detected: ${label} (${uuid})"
    uf_info "Ubuntuify needs a different ${target} implementation."
    if uf_is_true "$UF_ASSUME_YES"; then
      uf_warn "Keeping ${label} in automated mode; the ${target} component will be skipped."
      return 2
    fi
    local choice
    choice="$(uf_menu "How should ${label} be handled?" "Disable ${label} and continue" "Keep ${label} and skip this component" || true)"
    if [ -z "$choice" ] || [ "$choice" = "Keep ${label} and skip this component" ]; then
      uf_warn "Keeping ${label}; skipping the ${target} component."
      return 2
    fi
    uf_ext_disable "$uuid" "$label"
  done < <(printf '%s\n' "$rows")
  return 0
}

# uf_ext_disable_managed -- disable every extension Ubuntuify enabled.
uf_ext_disable_managed() {
  local value uuid
  if [ "$UF_DRY_RUN" -eq 0 ]; then
    uf_ext_cache_clear
  fi
  while IFS= read -r uuid; do
    [ -n "$uuid" ] || continue
    if uf_ext_uuid_installed "$uuid"; then
      uf_ext_disable "$uuid" "$uuid"
      uf_state_remove "managed_extensions" "$uuid"
      uf_state_remove "enabled_extensions" "$uuid"
    fi
  done < <(uf_state_list "managed_extensions")
  return 0
}

# uf_ext_component_guard NAME -- install/enable the extension for a component
# with conflict handling. Used by tray, dock, desktop icons and tiling.
# 0 = ready, 2 = skip component, 1 = failure.
uf_ext_component_guard() {
  local name="$1"
  uf_ext_load_registry || return 1
  if ! uf_ext_resolve_conflicts "$name"; then
    return 2
  fi
  uf_ext_ensure "$name"
}

# uf_ext_status -- component-style extension report.
uf_ext_status() {
  local name uuid enabled compatibility
  uf_ext_load_registry || return 1
  uf_section "GNOME extensions"
  for name in "${UF_EXT_NAMES[@]}"; do
    if uuid="$(uf_ext_resolve "$name")"; then
      compatibility="$(uf_ext_compatible "$uuid")"
      if uf_ext_is_enabled "$uuid"; then
        enabled="enabled"
      else
        enabled="disabled"
      fi
      printf '  %-20s %-48s %-9s %s\n' \
        "$(uf_style green '✓')" "$uuid" "$enabled" "compatible: ${compatibility}"
    else
      printf '  %-20s %s\n' "$(uf_style dim '○')" "${UF_EXT_LABEL[$name]} (not installed)"
    fi
  done
}

# uf_ext_installed_count -- number of installed GNOME extensions.
uf_ext_installed_count() {
  uf_ext_installed_uuids | sed '/^$/d' | wc -l | tr -d ' '
}
