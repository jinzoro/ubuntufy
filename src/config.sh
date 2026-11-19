# shellcheck shell=bash
# Configuration loading and validation.
#
# Precedence (highest first):
#   1. command line overrides
#   2. ~/.config/ubuntuify/config.conf
#   3. config/ubuntu-defaults.conf shipped with the project
#   4. built-in fallbacks in this file

declare -gA UF_CONF=()
declare -gA UF_CONF_OVERRIDES=()
UF_CONF_LOADED="${UF_CONF_LOADED:-0}"

UF_CONFIG_DEFAULTS_FILE="${UF_ROOT}/config/ubuntu-defaults.conf"

# uf_config_parse_file FILE -- load key=value lines. Comments must be on their
# own line, values are taken verbatim (quotes are stripped only when paired).
uf_config_parse_file() {
  local file="$1" line key value
  [ -r "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(uf_trim "$line")"
    [ -z "$line" ] && continue
    case "$line" in
      \#* | \;*) continue ;;
    esac
    case "$line" in
      *=*)
        key="$(uf_trim "${line%%=*}")"
        value="$(uf_trim "${line#*=}")"
        ;;
      *)
        uf_warn "Ignoring malformed configuration line in ${file}: ${line}"
        continue
        ;;
    esac
    if [ -z "$key" ]; then
      uf_warn "Ignoring configuration line with empty key in ${file}"
      continue
    fi
    if [[ ${#value} -ge 2 ]]; then
      local first="${value:0:1}" last="${value: -1}"
      if { [ "$first" = '"' ] && [ "$last" = '"' ]; } || { [ "$first" = "'" ] && [ "$last" = "'" ]; }; then
        value="${value:1:${#value}-2}"
      fi
    fi
    UF_CONF["$key"]="$value"
  done <"$file"
}

# uf_config_init -- load defaults then the user configuration file.
uf_config_init() {
  UF_CONF=()
  UF_CONF_LOADED=1
  if [ -r "$UF_CONFIG_DEFAULTS_FILE" ]; then
    uf_config_parse_file "$UF_CONFIG_DEFAULTS_FILE"
  fi
  if [ -r "$UF_USER_CONFIG" ]; then
    uf_debug "Loading user configuration ${UF_USER_CONFIG}"
    uf_config_parse_file "$UF_USER_CONFIG"
  fi
}

# uf_config_ensure -- lazy loader.
uf_config_ensure() {
  [ "${UF_CONF_LOADED:-0}" -eq 1 ] || uf_config_init
}

# uf_conf KEY [FALLBACK] -- read a configuration value.
uf_conf() {
  local key="$1" fallback="${2:-}"
  uf_config_ensure
  if [ -n "${UF_CONF_OVERRIDES[$key]:-}" ]; then
    printf '%s' "${UF_CONF_OVERRIDES[$key]}"
    return
  fi
  if [ -n "${UF_CONF[$key]:-}" ]; then
    printf '%s' "${UF_CONF[$key]}"
    return
  fi
  printf '%s' "$fallback"
}

# uf_conf_set KEY VALUE -- set a command-line override.
uf_conf_set() {
  UF_CONF_OVERRIDES["$1"]="$2"
}

# uf_config_persist KEY VALUE -- write one user configuration value without
# disturbing the rest of the file.
uf_config_persist() {
  local key="$1" value="$2" dir tmp line found=0
  dir="$(dirname -- "$UF_USER_CONFIG")"
  mkdir -p "$dir"
  uf_conf_set "$key" "$value"
  tmp="$(mktemp "${dir}/.config.XXXXXX")"
  if [ -f "$UF_USER_CONFIG" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "${key}="*)
          printf '%s=%s\n' "$key" "$value" >>"$tmp"
          found=1
          ;;
        *) printf '%s\n' "$line" >>"$tmp" ;;
      esac
    done <"$UF_USER_CONFIG"
  fi
  if [ "$found" -eq 0 ]; then
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  mv -- "$tmp" "$UF_USER_CONFIG"
}

# uf_conf_bool KEY [FALLBACK] -- read a boolean configuration value.
uf_conf_bool() {
  local value
  value="$(uf_conf "$1" "${2:-false}")"
  uf_is_true "$value"
}

# uf_conf_int KEY FALLBACK MIN MAX -- validated integer read.
uf_conf_int() {
  local key="$1" fallback="$2" min="$3" max="$4" value
  value="$(uf_conf "$key" "$fallback")"
  if ! uf_validate_int "$value" "$min" "$max"; then
    uf_warn "Invalid value '${value}' for ${key}; using ${fallback}."
    value="$fallback"
  fi
  printf '%s' "$value"
}

# uf_config_validate -- validate user-facing values. Problems are warnings:
# the last known default is used instead of aborting a whole installation.
uf_config_validate() {
  uf_config_ensure
  local errors=0 value

  value="$(uf_conf profile full)"
  case "$value" in
    full | minimal | dark | classic | custom) ;;
    *)
      uf_warn "Unknown profile '${value}' in configuration; falling back to 'full'."
      UF_CONF["profile"]="full"
      ;;
  esac

  value="$(uf_conf color_scheme default)"
  case "$value" in
    default | light | prefer-dark | dark) ;;
    *)
      uf_warn "Unknown color_scheme '${value}'; expected default or prefer-dark."
      UF_CONF["color_scheme"]="default"
      ;;
  esac

  value="$(uf_conf dock.position left)"
  case "$value" in
    left | right | bottom | top) ;;
    *)
      uf_warn "Unknown dock.position '${value}'; expected left, right, bottom or top."
      UF_CONF["dock.position"]="left"
      ;;
  esac

  value="$(uf_conf wallpaper.mode ask)"
  case "$value" in
    ask | ubuntu-default | keep | path) ;;
    /*) ;;
    *)
      uf_warn "Unknown wallpaper.mode '${value}'; expected ask, ubuntu-default, keep, path or an absolute path."
      UF_CONF["wallpaper.mode"]="ask"
      ;;
  esac

  value="$(uf_conf backup.keep 10)"
  if ! uf_validate_int "$value" 1 100; then
    uf_warn "backup.keep must be an integer between 1 and 100; using 10."
    UF_CONF["backup.keep"]="10"
  fi

  value="$(uf_conf online_extensions ask)"
  case "$value" in
    ask | yes | no | true | false) ;;
    *)
      uf_warn "online_extensions must be ask, yes or no; using ask."
      UF_CONF["online_extensions"]="ask"
      ;;
  esac

  value="$(uf_conf shortcuts.on_conflict keep)"
  case "$value" in
    ask | keep | replace) ;;
    *)
      uf_warn "shortcuts.on_conflict must be ask, keep or replace; using keep."
      UF_CONF["shortcuts.on_conflict"]="keep"
      ;;
  esac

  value="$(uf_conf dock.icon_size 48)"
  if ! uf_validate_int "$value" 16 128; then
    uf_warn "Invalid dock.icon_size '${value}'; using 48."
    UF_CONF["dock.icon_size"]="48"
  fi

  value="$(uf_conf cursor.size 24)"
  if ! uf_validate_int "$value" 16 128; then
    uf_warn "Invalid cursor.size '${value}'; using 24."
    UF_CONF["cursor.size"]="24"
  fi

  return "$errors"
}

# uf_config_show -- print effective configuration (used by --dry-run/status).
uf_config_show() {
  uf_config_ensure
  local key
  for key in $(printf '%s\n' "${!UF_CONF[@]}" | sort); do
    printf '%-28s %s\n' "$key" "$(uf_conf "$key")"
  done
}

# uf_config_sample -- print an example configuration for new users.
uf_config_sample() {
  cat <<'EOF'
# Ubuntuify Fedora - user configuration
# Everything here is optional; defaults live in config/ubuntu-defaults.conf.

profile=full
color_scheme=default

# theme=yaru
# icons=yaru
# cursor=yaru
# fonts=ubuntu

dock.position=left
dock.icon_size=48
dock.extend_height=true
dock.fixed=true
dock.autohide=false
dock.multi_monitor=false

desktop_icons.home=true
desktop_icons.trash=true
desktop_icons.volumes=true

tray=true
tiling=true
ubuntu_shortcuts=true

wallpaper.mode=ask
# wallpaper.path=/home/user/Pictures/my-wallpaper.png

plymouth=false
gdm=false
online_extensions=ask
backup.keep=10
EOF
}
