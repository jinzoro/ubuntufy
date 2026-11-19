# shellcheck shell=bash
# Safe GSettings abstraction.
#
# Rules enforced here:
#   * a schema must exist before a key is touched;
#   * a key must exist before it is written;
#   * enum/range values are validated when GSettings exposes them;
#   * values are recorded once so restore can put them back;
#   * missing optional settings are skipped, never fatal;
#   * dry-run mode writes nothing.

declare -gA UF_GS_SCHEMA_CACHE=()
declare -gA UF_GS_KEY_CACHE=()
declare -gA UF_GS_RANGE_CACHE=()
UF_GS_CACHE_LOADED="${UF_GS_CACHE_LOADED:-0}"
UF_GS_FAILED="${UF_GS_FAILED:-0}"

# uf_gs_load_schemas -- populate the schema cache once.
uf_gs_load_schemas() {
  [ "${UF_GS_CACHE_LOADED:-0}" -eq 1 ] && return 0
  UF_GS_CACHE_LOADED=1
  local schema
  if ! uf_have gsettings; then
    return 0
  fi
  while IFS= read -r schema; do
    [ -n "$schema" ] && UF_GS_SCHEMA_CACHE["$schema"]=1
  done < <(gsettings list-schemas 2>/dev/null || true)
}

# uf_gs_schema_exists SCHEMA
uf_gs_schema_exists() {
  uf_gs_load_schemas
  [ -n "${UF_GS_SCHEMA_CACHE[${1:-}]:-}" ]
}

# uf_gs_schemas -- list installed schemas.
uf_gs_schemas() {
  uf_gs_load_schemas
  local schema
  for schema in "${!UF_GS_SCHEMA_CACHE[@]}"; do
    printf '%s\n' "$schema"
  done | sort
}

# uf_gs_key_exists SCHEMA KEY
uf_gs_key_exists() {
  local schema="$1" key="$2" keys
  uf_gs_schema_exists "$schema" || return 1
  if [ -z "${UF_GS_KEY_CACHE[$schema]:-}" ]; then
    keys="$(gsettings list-keys "$schema" 2>/dev/null || true)"
    UF_GS_KEY_CACHE["$schema"]="$keys"
  fi
  grep -qx -- "$key" <<<"${UF_GS_KEY_CACHE[$schema]}"
}

# uf_gs_value_allowed SCHEMA KEY VALUE -- best-effort GVariant validation.
uf_gs_value_allowed() {
  local schema="$1" key="$2" value="$3" range first_line bounds line min max
  range="$(gsettings range "$schema" "$key" 2>/dev/null || true)"
  [ -n "$range" ] || return 0
  first_line="$(uf_first_line "$range")"
  case "$first_line" in
    enum)
      while IFS= read -r line; do
        [ "$line" = "$value" ] && return 0
      done < <(printf '%s\n' "$range" | tail -n +2)
      return 1
      ;;
    type*)
      bounds="$(printf '%s\n' "$range" | sed -n '2p')"
      case "$bounds" in
        range\ *)
          min="$(printf '%s\n' "$bounds" | awk '{print $2}')"
          max="$(printf '%s\n' "$bounds" | awk '{print $3}')"
          if [[ $value =~ ^-?[0-9]+$ ]] && [[ $min =~ ^-?[0-9]+$ ]] && [[ $max =~ ^-?[0-9]+$ ]]; then
            if ((value < min || value > max)); then
              return 1
            fi
          fi
          ;;
      esac
      ;;
  esac
  return 0
}

# uf_gs_get SCHEMA KEY -- raw GVariant text, empty on error.
uf_gs_get() {
  local schema="$1" key="$2"
  uf_gs_key_exists "$schema" "$key" || return 1
  gsettings get "$schema" "$key" 2>/dev/null
}

# uf_gs_record_original SCHEMA KEY VALUE
uf_gs_record_original() {
  local schema="$1" key="$2" value="$3" component="${UF_CURRENT_COMPONENT:-manual}"
  local line_schema line_key _line_value _line_component
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  mkdir -p "$UF_STATE_DIR"
  if [ -f "$UF_ORIGINAL_SETTINGS" ]; then
    while IFS=$'\t' read -r line_schema line_key _line_value _line_component; do
      if [ "$line_schema" = "$schema" ] && [ "$line_key" = "$key" ]; then
        return 0
      fi
    done <"$UF_ORIGINAL_SETTINGS"
  fi
  printf '%s\t%s\t%s\t%s\n' "$schema" "$key" "$value" "$component" >>"$UF_ORIGINAL_SETTINGS"
}

# uf_gs_record_applied SCHEMA KEY VALUE
uf_gs_record_applied() {
  local schema="$1" key="$2" value="$3" component="${UF_CURRENT_COMPONENT:-manual}"
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  mkdir -p "$UF_STATE_DIR"
  printf '%s\t%s\t%s\t%s\n' "$component" "$schema" "$key" "$value" >>"$UF_APPLIED_SETTINGS"
}

# uf_gs_set SCHEMA KEY VALUE [LABEL]
#
# Returns 0 even when a setting is unavailable or fails: a single optional
# setting must never abort the installer. Failures increment UF_GS_FAILED.
uf_gs_set() {
  local schema="$1" key="$2" value="$3" label="${4:-$2}" current
  if ! uf_gs_schema_exists "$schema"; then
    uf_skip "Settings schema unavailable on this system: ${schema} (${label})"
    return 0
  fi
  if ! uf_gs_key_exists "$schema" "$key"; then
    uf_skip "Setting unavailable on this GNOME version: ${schema} ${key} (${label})"
    return 0
  fi
  if ! uf_gs_value_allowed "$schema" "$key" "$value"; then
    uf_skip "Value ${value} is not allowed for ${schema} ${key} (${label})"
    return 0
  fi

  current="$(gsettings get "$schema" "$key" 2>/dev/null || true)"
  if [ "$current" = "$value" ]; then
    uf_debug "No change: ${schema} ${key} is already ${value}"
    return 0
  fi

  uf_gs_record_original "$schema" "$key" "$current"

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would set ${label}: ${value} (was ${current})"
    return 0
  fi

  local error_output
  if error_output="$(gsettings set "$schema" "$key" "$value" 2>&1)"; then
    uf_ok "Set ${label}: ${value}"
    uf_gs_record_applied "$schema" "$key" "$value"
    UF_CHANGED_COUNT=$((UF_CHANGED_COUNT + 1))
  else
    uf_warn "Could not set ${label} (${schema} ${key}): ${error_output:-unknown error}"
    UF_GS_FAILED=$((UF_GS_FAILED + 1))
  fi
  return 0
}

# uf_setting -- alias kept short for the configuration modules.
uf_setting() {
  uf_gs_set "$@"
}

# uf_gs_force_set SCHEMA KEY VALUE -- write without recording. Restore only.
uf_gs_force_set() {
  local schema="$1" key="$2" value="$3"
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would restore ${schema} ${key} = ${value}"
    return 0
  fi
  if ! uf_gs_key_exists "$schema" "$key"; then
    uf_skip "Cannot restore unknown setting ${schema} ${key}"
    return 0
  fi
  if gsettings set "$schema" "$key" "$value" >/dev/null 2>&1; then
    uf_debug "Restored ${schema} ${key} = ${value}"
    return 0
  fi
  uf_warn "Could not restore ${schema} ${key} = ${value}"
  return 0
}

# uf_gs_reset SCHEMA KEY
uf_gs_reset() {
  local schema="$1" key="$2"
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would reset ${schema} ${key}"
    return 0
  fi
  if uf_gs_key_exists "$schema" "$key"; then
    gsettings reset "$schema" "$key" >/dev/null 2>&1 || uf_warn "Could not reset ${schema} ${key}"
  fi
}

# uf_gs_original_lookup SCHEMA KEY -- print the recorded original value.
uf_gs_original_lookup() {
  local schema="$1" key="$2" line_schema line_key value _component
  [ -f "$UF_ORIGINAL_SETTINGS" ] || return 1
  while IFS=$'\t' read -r line_schema line_key value _component; do
    if [ "$line_schema" = "$schema" ] && [ "$line_key" = "$key" ]; then
      printf '%s\n' "$value"
      return 0
    fi
  done <"$UF_ORIGINAL_SETTINGS"
  return 1
}

# uf_gs_restore_originals [COMPONENT] -- put back values recorded before
# Ubuntuify changed them. Without COMPONENT, every recorded value is restored.
uf_gs_restore_originals() {
  local filter="${1:-}" schema key value component restored=0
  [ -f "$UF_ORIGINAL_SETTINGS" ] || {
    uf_debug "No recorded original settings"
    return 0
  }
  local remaining="" line
  while IFS=$'\t' read -r schema key value component; do
    [ -n "$schema" ] || continue
    if [ -n "$filter" ] && [ "$component" != "$filter" ]; then
      remaining+="${schema}"$'\t'"${key}"$'\t'"${value}"$'\t'"${component}"$'\n'
      continue
    fi
    uf_gs_force_set "$schema" "$key" "$value"
    restored=$((restored + 1))
  done <"$UF_ORIGINAL_SETTINGS"
  if [ -n "$filter" ] && [ "$UF_DRY_RUN" -eq 0 ]; then
    printf '%s' "$remaining" >"$UF_ORIGINAL_SETTINGS"
  fi
  uf_info "Restored ${restored} original setting(s)${filter:+ for component ${filter}}"
}

# uf_gs_reset_managed [COMPONENT] -- reset values that Ubuntuify set and that
# the user has not changed since. Unlike restore, user edits are preserved.
uf_gs_reset_managed() {
  local filter="${1:-}" component schema key value current original
  declare -A seen=()
  [ -f "$UF_APPLIED_SETTINGS" ] || return 0
  local total=0 kept=0 idx line
  local -a lines=()
  mapfile -t lines <"$UF_APPLIED_SETTINGS"
  # Walk backwards so the newest applied value wins for a key that was changed
  # across several profile switches.
  for ((idx = ${#lines[@]} - 1; idx >= 0; idx--)); do
    line="${lines[$idx]}"
    [ -n "$line" ] || continue
    IFS=$'\t' read -r component schema key value <<<"$line"
    [ -n "$schema" ] || continue
    if [ -n "$filter" ] && [ "$component" != "$filter" ]; then
      continue
    fi
    [ -n "${seen["${schema}|${key}"]:-}" ] && continue
    seen["${schema}|${key}"]=1
    current="$(uf_gs_get "$schema" "$key" || true)"
    if [ "$current" != "$value" ]; then
      uf_info "Keeping user change for ${schema} ${key} (current ${current})"
      kept=$((kept + 1))
      continue
    fi
    if original="$(uf_gs_original_lookup "$schema" "$key")"; then
      uf_gs_force_set "$schema" "$key" "$original"
    else
      uf_gs_reset "$schema" "$key"
    fi
    total=$((total + 1))
  done
  uf_info "Reset ${total} Ubuntuify-managed setting(s)"
  [ "$kept" -gt 0 ] && uf_info "Preserved ${kept} setting(s) changed by the user"
  return 0
}

# uf_gs_is_set SCHEMA KEY VALUE -- true when the current value matches.
uf_gs_is_set() {
  local current
  current="$(uf_gs_get "$1" "$2" || true)"
  [ -n "$current" ] && [ "$current" = "$3" ]
}

# uf_gs_value SCHEMA KEY [FALLBACK] -- display-friendly current value.
uf_gs_value() {
  local value
  value="$(uf_gs_get "$1" "$2" || true)"
  if [ -z "$value" ]; then
    printf '%s' "${3:-unknown}"
    return
  fi
  value="${value#\'}"
  value="${value%\'}"
  value="${value#\[}"
  value="${value%\]}"
  printf '%s' "$value"
}
