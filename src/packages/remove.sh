# shellcheck shell=bash
# Package cleanup. Never removes packages that existed before Ubuntuify.

# uf_pkg_managed_list -- packages Ubuntuify installed, one per line.
uf_pkg_managed_list() {
  local value
  value="$(uf_state_get installed_packages 2>/dev/null || true)"
  [ -n "$value" ] || return 0
  python3 - "$value" <<'PY'
import json
import sys

raw = sys.argv[1]
try:
    items = json.loads(raw)
except json.JSONDecodeError:
    items = [item.strip() for item in raw.split(",") if item.strip()]
if isinstance(items, list):
    for item in items:
        if isinstance(item, str):
            print(item)
PY
}

# uf_pkg_remove_managed -- remove packages recorded as installed by Ubuntuify.
uf_pkg_remove_managed() {
  local packages=() package
  while IFS= read -r package; do
    [ -n "$package" ] && packages+=("$package")
  done < <(uf_pkg_managed_list)

  if [ "${#packages[@]}" -eq 0 ]; then
    uf_info "No packages were installed by Ubuntuify; nothing to remove."
    return 0
  fi

  uf_section "Packages installed by Ubuntuify"
  for package in "${packages[@]}"; do
    printf '  %s\n' "$package"
  done

  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would remove ${#packages[@]} Ubuntuify-installed package(s)"
    return 0
  fi
  if ! uf_confirm "Remove these packages? Packages that existed before Ubuntuify are never listed." n; then
    uf_info "Keeping packages. Run 'ubuntuify uninstall --remove-packages' later if you change your mind."
    return 0
  fi
  if ! uf_have dnf; then
    uf_warn "DNF not available; cannot remove packages."
    return 1
  fi

  if uf_run_root dnf remove -y -- "${packages[@]}"; then
    for package in "${packages[@]}"; do
      uf_state_remove "installed_packages" "$package"
    done
    uf_ok "Removed ${#packages[@]} package(s)"
    return 0
  fi
  uf_warn "Package removal failed; run 'sudo dnf remove ${packages[*]}' manually if needed."
  return 1
}

# uf_pkg_state_report -- show what was present before vs installed by us.
uf_pkg_state_report() {
  local package list=()
  uf_section "Package state"

  printf '%s\n' "$(uf_style bold 'Installed by Ubuntuify:')"
  while IFS= read -r package; do
    [ -n "$package" ] && list+=("$package")
  done < <(uf_pkg_managed_list)
  if [ "${#list[@]}" -eq 0 ]; then
    printf '  (none)\n'
  else
    for package in "${list[@]}"; do
      printf '  %s\n' "$package"
    done
  fi

  local latest
  latest="$(uf_backup_latest 2>/dev/null || true)"
  if [ -n "$latest" ] && [ -f "${UF_BACKUP_ROOT}/${latest}/packages-before.txt" ]; then
    printf '\n%s\n' "$(uf_style bold 'Installed before Ubuntuify (snapshot):')"
    printf '  %s packages recorded in backup %s\n' \
      "$(wc -l <"${UF_BACKUP_ROOT}/${latest}/packages-before.txt" | tr -d ' ')" "$latest"
  else
    printf '\n%s\n' "$(uf_style dim 'No pre-install package snapshot available.')"
  fi
}
