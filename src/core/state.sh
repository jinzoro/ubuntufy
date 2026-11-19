# shellcheck shell=bash
# State file helpers.
#
# state.json is a convenience cache, never a source of truth: every status
# check verifies the live system and treats the file as advisory.

UF_STATE_PY="${UF_SRC}/core/state.py"

# uf_state_init -- create directories and a state file if missing.
uf_state_init() {
  mkdir -p "$UF_STATE_DIR"
  if [ ! -f "$UF_STATE_FILE" ]; then
    python3 "$UF_STATE_PY" init "$UF_STATE_FILE"
  fi
  touch "$UF_ORIGINAL_SETTINGS" "$UF_APPLIED_SETTINGS" 2>/dev/null || true
}

# uf_state_exists -- true when a state file exists.
uf_state_exists() {
  [ -s "$UF_STATE_FILE" ]
}

# uf_state_get KEY -- print a value from state.json.
uf_state_get() {
  [ -f "$UF_STATE_FILE" ] || return 1
  python3 "$UF_STATE_PY" get "$UF_STATE_FILE" "$1" 2>/dev/null || true
}

# uf_state_set KEY VALUE -- write a value.
uf_state_set() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  uf_state_init
  python3 "$UF_STATE_PY" set "$UF_STATE_FILE" "$1" "$2"
}

# uf_state_add KEY VALUE -- append VALUE to a list in state.
uf_state_add() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  uf_state_init
  python3 "$UF_STATE_PY" add "$UF_STATE_FILE" "$1" "$2"
}

# uf_state_remove KEY VALUE -- remove VALUE from a list in state.
uf_state_remove() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  [ -f "$UF_STATE_FILE" ] || return 0
  python3 "$UF_STATE_PY" remove "$UF_STATE_FILE" "$1" "$2"
}

# uf_state_list KEY -- print list entries, one per line.
uf_state_list() {
  [ -f "$UF_STATE_FILE" ] || return 0
  python3 "$UF_STATE_PY" list-get "$UF_STATE_FILE" "$1" 2>/dev/null || true
}

# uf_state_has KEY VALUE -- membership test.
uf_state_has() {
  [ -f "$UF_STATE_FILE" ] || return 1
  python3 "$UF_STATE_PY" has "$UF_STATE_FILE" "$1" "$2" >/dev/null 2>&1
}

# uf_state_delete KEY -- delete a key.
uf_state_delete() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  [ -f "$UF_STATE_FILE" ] || return 0
  python3 "$UF_STATE_PY" delete "$UF_STATE_FILE" "$1" 2>/dev/null || true
}

# uf_state_component_set NAME STATUS -- record component outcome.
uf_state_component_set() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  uf_state_init
  python3 "$UF_STATE_PY" component-set "$UF_STATE_FILE" "$1" "$2"
}

# uf_state_component_get NAME -- print a component status.
uf_state_component_get() {
  [ -f "$UF_STATE_FILE" ] || return 1
  python3 "$UF_STATE_PY" component-get "$UF_STATE_FILE" "$1" 2>/dev/null || true
}

# uf_state_dump -- print the whole state file.
uf_state_dump() {
  if [ ! -f "$UF_STATE_FILE" ]; then
    printf '{}\n'
    return 0
  fi
  python3 "$UF_STATE_PY" dump "$UF_STATE_FILE"
}

# uf_state_update_system -- refresh detected versions and session in state.
uf_state_update_system() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  uf_detect_all
  uf_state_set "fedora_version" "${UF_DISTRO_VERSION_ID:-unknown}"
  uf_state_set "gnome_version" "${UF_GNOME_VERSION:-unknown}"
  uf_state_set "session" "${UF_SESSION_TYPE:-unknown}"
  uf_state_set "version" "$UF_VERSION"
  uf_state_set "schema" "$UF_STATE_SCHEMA_VERSION"
}

# uf_state_reset -- remove Ubuntuify state, keeping backups and logs.
uf_state_reset() {
  [ "$UF_DRY_RUN" -eq 1 ] && return 0
  rm -f -- "$UF_STATE_FILE" "$UF_ORIGINAL_SETTINGS" "$UF_APPLIED_SETTINGS" 2>/dev/null || true
}
