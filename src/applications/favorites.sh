# shellcheck shell=bash
# Ubuntu-like application favorites.
#
# Only .desktop files that really exist are used. Missing applications are
# skipped, never fabricated.

# uf_desktop_dirs -- application directories searched for .desktop files.
uf_desktop_dirs() {
  printf '%s\n' \
    "/usr/share/applications" \
    "/usr/local/share/applications" \
    "${HOME}/.local/share/applications" \
    "/var/lib/flatpak/exports/share/applications" \
    "${HOME}/.local/share/flatpak/exports/share/applications" \
    "/var/lib/snapd/desktop/applications"
}

# uf_desktop_file_exists NAME
uf_desktop_file_exists() {
  local name="$1" dir
  [ -n "$name" ] || return 1
  while IFS= read -r dir; do
    if [ -f "${dir}/${name}" ]; then
      return 0
    fi
  done < <(uf_desktop_dirs)
  return 1
}

# uf_desktop_file_resolve CANDIDATES -- first existing candidate (| separated).
uf_desktop_file_resolve() {
  local candidates="$1" candidate
  while IFS= read -r candidate; do
    if uf_desktop_file_exists "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(uf_split_list '|' "$candidates")
  return 1
}

# uf_favorites_defaults -- print the desktop files Ubuntu's default favorites
# resolve to on this system.
uf_favorites_defaults() {
  local list entry resolved
  list="$(uf_conf favorites.list '')"
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    if resolved="$(uf_desktop_file_resolve "$entry")"; then
      printf '%s\n' "$resolved"
    else
      uf_debug "Favorite not installed, skipping: ${entry}"
    fi
  done < <(uf_split_list ';' "$list")
}

# uf_favorites_merge CURRENT NEW -- merge two newline separated lists.
uf_favorites_merge() {
  local current="$1" new="$2" item
  local out=""
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    out="$(uf_list_add_unique "$out" "$item" $'\n')"
  done <<<"$current"
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    out="$(uf_list_add_unique "$out" "$item" $'\n')"
  done <<<"$new"
  printf '%s\n' "$out"
}

# uf_favorites_format LIST -- turn newline separated items into GVariant.
uf_favorites_format() {
  local list="$1" item out="" first=1
  while IFS= read -r item; do
    [ -n "$item" ] || continue
    if [ "$first" -eq 1 ]; then
      out="'"$item"'"
      first=0
    else
      out+=", '"$item"'"
    fi
  done <<<"$list"
  printf '[%s]' "$out"
}

# uf_favorites_apply -- apply Ubuntu-like favorites without destroying the
# user's existing selection.
uf_favorites_apply() {
  local current_raw current new_list final desired

  if ! uf_conf_bool "favorites.enabled" true; then
    uf_skip "Favorites disabled in configuration."
    return 0
  fi

  desired="$(uf_favorites_defaults)"
  if [ -z "$desired" ]; then
    uf_warn "None of the Ubuntu default applications are installed; keeping current favorites."
    return 2
  fi

  current_raw="$(uf_gs_get org.gnome.shell favorite-apps 2>/dev/null || printf '[]')"
  current="$(python3 "${UF_SRC}/core/gvariant.py" list-get "$current_raw" 2>/dev/null || true)"

  local merge=1
  if [ "$(uf_conf favorites.merge true)" != "true" ]; then
    merge=0
  fi

  if [ -n "$current" ]; then
    local current_sorted desired_sorted
    current_sorted="$(printf '%s\n' "$current" | sort)"
    desired_sorted="$(printf '%s\n' "$desired" | sort)"
    if [ "$current_sorted" != "$desired_sorted" ] && [ "$UF_ASSUME_YES" -eq 0 ] && [ -t 0 ]; then
      local choice
      choice="$(uf_menu "Your favorite applications differ from Ubuntu's defaults." \
        "Merge: keep mine and add Ubuntu's defaults" \
        "Replace mine with Ubuntu's defaults" \
        "Keep my current favorites" || true)"
      case "$choice" in
        "Replace mine with Ubuntu's defaults") merge=1; current="" ;;
        "Keep my current favorites") uf_info "Keeping current favorites."; return 0 ;;
        "") uf_info "Keeping current favorites."; return 0 ;;
        *) merge=1 ;;
      esac
    fi
  fi

  if [ -n "$current" ] && [ "$merge" -eq 1 ]; then
    new_list="$(uf_favorites_merge "$current" "$desired")"
  else
    new_list="$desired"
  fi

  final="$(uf_favorites_format "$new_list")"
  if [ "$final" = "$current_raw" ]; then
    uf_debug "Favorites already configured"
    return 0
  fi
  uf_gs_set org.gnome.shell favorite-apps "$final" "Favorite applications"
  return 0
}
