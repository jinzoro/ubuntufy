# shellcheck shell=bash
# Small, dependency-free helpers used across Ubuntuify.

# uf_have COMMAND -- true when COMMAND is on PATH.
uf_have() {
  command -v "$1" >/dev/null 2>&1
}

# uf_is_true VALUE -- normalise common boolean spellings.
uf_is_true() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | on | enabled | Enabled) return 0 ;;
    *) return 1 ;;
  esac
}

# uf_trim STRING -- strip leading and trailing whitespace.
uf_trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# uf_lower STRING -- ASCII lowercase (locale independent).
uf_lower() {
  printf '%s' "${1-}" | LC_ALL=C tr '[:upper:]' '[:lower:]'
}

# uf_repeat CHAR COUNT -- repeat CHAR COUNT times.
uf_repeat() {
  local char="${1-─}" count="${2:-0}" out=""
  local i
  for ((i = 0; i < count; i++)); do
    out+="$char"
  done
  printf '%s' "$out"
}

# uf_now -- local timestamp usable in directory names.
uf_now() {
  date '+%Y-%m-%d-%H%M%S'
}

# uf_datetime -- human readable timestamp for logs and reports.
uf_datetime() {
  date '+%Y-%m-%d %H:%M:%S'
}

# uf_date -- short date for reports.
uf_date() {
  date '+%Y-%m-%d'
}

# uf_validate_int VALUE [MIN] [MAX]
uf_validate_int() {
  local value="${1-}" min="${2:-}" max="${3:-}"
  [[ $value =~ ^-?[0-9]+$ ]] || return 1
  if [ -n "$min" ] && ((value < min)); then return 1; fi
  if [ -n "$max" ] && ((value > max)); then return 1; fi
  return 0
}

# uf_confirm PROMPT [DEFAULT] -- ask a yes/no question.
#
# Honours --yes, which always answers yes. When stdin is not a terminal the
# default answer is used and the assumption is logged, so automation is safe.
uf_confirm() {
  local prompt="$1" default="${2:-n}" answer=""
  if uf_is_true "$UF_ASSUME_YES"; then
    uf_debug "Assuming yes for: ${prompt}"
    return 0
  fi
  if [ ! -t 0 ]; then
    uf_debug "Non-interactive: using default '${default}' for: ${prompt}"
    [ "$default" = "y" ]
    return
  fi
  if [ "$default" = "y" ]; then
    read -r -p "${prompt} [Y/n] " answer || answer=""
  else
    read -r -p "${prompt} [y/N] " answer || answer=""
  fi
  answer="$(uf_lower "$(uf_trim "$answer")")"
  if [ -z "$answer" ]; then
    [ "$default" = "y" ]
    return
  fi
  case "$answer" in
    y | yes) return 0 ;;
    *) return 1 ;;
  esac
}

# uf_ask PROMPT -- free-form answer. Empty when non-interactive.
uf_ask() {
  local prompt="$1" answer=""
  if [ ! -t 0 ]; then
    return 0
  fi
  read -r -p "$prompt " answer || answer=""
  printf '%s' "$(uf_trim "$answer")"
}

# uf_menu TITLE OPTION... -- numbered menu, prints the chosen option to stdout.
# Returns 1 when the user aborts or the terminal is not interactive.
uf_menu() {
  local title="$1"
  shift
  local options=("$@") choice i
  if [ ! -t 0 ]; then
    return 1
  fi
  printf '\n%s\n' "$(uf_style bold "$title")"
  for i in "${!options[@]}"; do
    printf '  %2d) %s\n' "$((i + 1))" "${options[$i]}"
  done
  printf '   0) Back / cancel\n'
  read -r -p "Select: " choice || return 1
  choice="$(uf_trim "$choice")"
  if [ -z "$choice" ] || [ "$choice" = "0" ]; then
    return 1
  fi
  if ! uf_validate_int "$choice" 1 "${#options[@]}"; then
    uf_warn "Invalid selection: ${choice}"
    return 1
  fi
  printf '%s' "${options[$((choice - 1))]}"
}

# uf_realpath PATH -- resolve an existing path without readlink -f portability
# problems.
uf_realpath() {
  local path="${1-}"
  if [ -d "$path" ]; then
    (cd -- "$path" && pwd -P)
  elif [ -e "$path" ]; then
    local dir base
    dir="$(dirname -- "$path")"
    base="$(basename -- "$path")"
    printf '%s/%s' "$(cd -- "$dir" && pwd -P)" "$base"
  else
    return 1
  fi
}

# uf_safe_remove_tree PATH -- remove a directory only inside Ubuntuify state.
# Refuses empty paths, "/", and anything outside UF_STATE_HOME.
uf_safe_remove_tree() {
  local path="${1-}" resolved root
  if [ -z "$path" ]; then
    uf_error "Refusing to remove an empty path."
    return 1
  fi
  resolved="$(uf_realpath "$path" 2>/dev/null)" || {
    uf_debug "Path already absent: $path"
    return 0
  }
  if ! root="$(uf_realpath "$UF_STATE_HOME")"; then
    uf_error "Ubuntuify state directory does not exist; refusing to remove ${resolved}."
    return 1
  fi
  case "$resolved" in
    "$root"/*) ;;
    *)
      uf_error "Refusing to remove path outside Ubuntuify state: $resolved"
      return 1
      ;;
  esac
  if [ "$resolved" = "/" ] || [ "$resolved" = "$HOME" ]; then
    uf_error "Refusing to remove protected path: $resolved"
    return 1
  fi
  rm -rf -- "$resolved"
}

# uf_join_by SEP ITEM... -- join items on stdout.
uf_join_by() {
  local sep="$1"
  shift
  local out="" item
  for item in "$@"; do
    if [ -z "$out" ]; then
      out="$item"
    else
      out+="${sep}${item}"
    fi
  done
  printf '%s' "$out"
}

# uf_split_list SEP STRING -- split a string on a single-character separator.
# Each element is printed on its own line; empty elements are dropped.
uf_split_list() {
  local sep="${1-;}" value="${2-}" item
  local -a parts=()
  # read -a splits on IFS without pathname expansion, unlike an unquoted $value.
  IFS="$sep" read -ra parts <<<"$value"
  for item in "${parts[@]}"; do
    [ -n "$item" ] && printf '%s\n' "$item"
  done
}

# uf_contains LIST_STRING SEP ITEM -- membership test for simple lists.
uf_contains() {
  local list="${1-}" sep="${2-;}" needle="${3-}" item
  local -a parts=()
  IFS="$sep" read -ra parts <<<"$list"
  for item in "${parts[@]}"; do
    if [ "$item" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

# uf_list_add_unique LIST ITEM [SEP] -- add ITEM to LIST unless present.
uf_list_add_unique() {
  local list="${1-}" item="${2-}" sep="${3:-;}"
  if [ -z "$list" ]; then
    printf '%s' "$item"
    return
  fi
  if uf_contains "$list" "$sep" "$item"; then
    printf '%s' "$list"
    return
  fi
  printf '%s%s%s' "$list" "$sep" "$item"
}

# uf_first_line STRING -- first line of a possibly multi-line string.
uf_first_line() {
  printf '%s\n' "${1-}" | head -n 1
}

# uf_command_stdout CMD... -- run a command, return stdout, never fail the
# caller because of a missing command.
uf_try() {
  "$@" 2>/dev/null || true
}

# uf_require_command COMMAND [PACKAGE] -- fail with an actionable message.
uf_require_command() {
  local cmd="$1" package="${2:-$1}"
  if ! uf_have "$cmd"; then
    uf_die "Required command '${cmd}' is missing. Install it with: sudo dnf install ${package}"
  fi
}

# uf_shellcheck_quote -- helper used by tests to assert values are untouched.
uf_printable() {
  printf '%s' "${1-}" | LC_ALL=C tr -cd '[:print:][:space:]'
}
