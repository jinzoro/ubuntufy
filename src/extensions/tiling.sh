# shellcheck shell=bash
# Ubuntu-compatible window tiling through Tiling Assistant.
#
# Only one tiling extension is enabled at a time; conflicts are handled by the
# extension manager before this module runs.

UF_TILING_SCHEMA="org.gnome.shell.extensions.tiling-assistant"

uf_tiling_apply() {
  if ! uf_conf_bool "tiling.enabled" true; then
    uf_skip "Tiling disabled in configuration."
    return 0
  fi

  local guard_rc=0
  uf_ext_component_guard "tiling" || guard_rc=$?
  if [ "$guard_rc" -eq 2 ]; then
    uf_warn "Tiling Assistant is unavailable; GNOME's built-in edge tiling remains active."
    return 2
  elif [ "$guard_rc" -ne 0 ]; then
    uf_warn "Tiling Assistant could not be enabled."
    return 1
  fi

  if ! uf_gs_schema_exists "$UF_TILING_SCHEMA"; then
    uf_warn "Tiling Assistant settings schema not found; enable it after the next login and rerun 'ubuntuify install --component tiling'."
    return 2
  fi

  # Key names have changed across Tiling Assistant releases; only existing
  # keys are written.
  local key
  for key in enable-tiling enable-quarter-tiling enable-snap-assist enable-window-drag; do
    if uf_gs_key_exists "$UF_TILING_SCHEMA" "$key"; then
      uf_gs_set "$UF_TILING_SCHEMA" "$key" true "Tiling: ${key}"
    fi
  done

  uf_ok "Tiling Assistant configured"
  return 0
}
