# shellcheck shell=bash
# Terminal output and log file handling.
#
# Every message is prefixed with a stable tag so scripts and humans can parse
# output: [INFO] [OK] [WARN] [ERROR] [SKIP] [DRY-RUN] [DEBUG].

UF_LOG_FILE="${UF_LOG_FILE:-}"

# uf_color_enabled -- use colour only on a terminal that supports it.
uf_color_enabled() {
  [ "${UF_NO_COLOR:-0}" -eq 0 ] || return 1
  [ -n "${NO_COLOR:-}" ] && return 1
  [ -t 1 ]
}

# uf_style STYLE TEXT -- wrap TEXT in an ANSI style when colour is enabled.
uf_style() {
  local style="$1" text="$2"
  if ! uf_color_enabled; then
    printf '%s' "$text"
    return
  fi
  case "$style" in
    bold) printf '\033[1m%s\033[0m' "$text" ;;
    dim) printf '\033[2m%s\033[0m' "$text" ;;
    red) printf '\033[31m%s\033[0m' "$text" ;;
    green) printf '\033[32m%s\033[0m' "$text" ;;
    yellow) printf '\033[33m%s\033[0m' "$text" ;;
    blue) printf '\033[34m%s\033[0m' "$text" ;;
    magenta) printf '\033[35m%s\033[0m' "$text" ;;
    cyan) printf '\033[36m%s\033[0m' "$text" ;;
    *) printf '%s' "$text" ;;
  esac
}

# uf_log_init -- create a log file for this run.
uf_log_init() {
  if [ -n "${UF_LOG_FILE:-}" ]; then
    return 0
  fi
  mkdir -p "$UF_LOG_DIR"
  UF_LOG_FILE="$UF_LOG_DIR/ubuntuify-$(date '+%Y%m%d-%H%M%S')-$$.log"
  if ! : >"$UF_LOG_FILE" 2>/dev/null; then
    UF_LOG_FILE=""
    return 1
  fi
  {
    printf '# %s %s\n' "$UF_NAME" "$UF_VERSION"
    printf '# started %s\n' "$(uf_datetime)"
    printf '# host %s\n' "$(uname -n 2>/dev/null || printf unknown)"
  } >"$UF_LOG_FILE"
  return 0
}

# uf_log_write LEVEL MESSAGE -- append a line to the log file.
uf_log_write() {
  local level="$1" message="$2"
  [ -n "${UF_LOG_FILE:-}" ] || return 0
  printf '%s %-5s %s\n' "$(uf_datetime)" "$level" "$message" >>"$UF_LOG_FILE" 2>/dev/null || true
}

# uf_msg LEVEL MESSAGE -- print and log a message.
uf_msg() {
  local level="$1" message="$2" tag style
  case "$level" in
    INFO) tag="[INFO]" style="blue" ;;
    OK) tag="[OK]" style="green" ;;
    WARN) tag="[WARN]" style="yellow" ;;
    ERROR) tag="[ERROR]" style="red" ;;
    SKIP) tag="[SKIP]" style="dim" ;;
    DRY) tag="[DRY-RUN]" style="cyan" ;;
    DEBUG) tag="[DEBUG]" style="dim" ;;
    *) tag="[${level}]" style="plain" ;;
  esac

  uf_log_write "$level" "$message"

  case "$level" in
    DEBUG)
      [ "${UF_VERBOSE:-0}" -eq 1 ] || return 0
      ;;
    INFO | OK | SKIP)
      [ "${UF_QUIET:-0}" -eq 0 ] || return 0
      ;;
    WARN) UF_WARN_COUNT=$((UF_WARN_COUNT + 1)) ;;
    ERROR) UF_ERROR_COUNT=$((UF_ERROR_COUNT + 1)) ;;
  esac

  # Diagnostics go to stderr so callers can safely use command substitution
  # to capture values (paths, component lists, selected packages).
  printf '%s %s\n' "$(uf_style "$style" "$tag")" "$message" >&2
}

uf_info() { uf_msg INFO "$*"; }
uf_ok() { uf_msg OK "$*"; }
uf_warn() { uf_msg WARN "$*"; }
uf_error() { uf_msg ERROR "$*"; }
uf_skip() { uf_msg SKIP "$*"; UF_SKIP_COUNT=$((UF_SKIP_COUNT + 1)); }
uf_dry() { uf_msg DRY "$*"; }
uf_debug() { uf_msg DEBUG "$*"; }

# uf_step MESSAGE -- a low-key action line.
uf_step() {
  uf_log_write "STEP" "$*"
  if [ "${UF_QUIET:-0}" -eq 0 ]; then
    printf '%s %s\n' "$(uf_style cyan '→')" "$*" >&2
  fi
}

# uf_section TITLE -- a section heading with underline.
uf_section() {
  local title="$1"
  [ "${UF_QUIET:-0}" -eq 0 ] || return 0
  printf '\n%s\n%s\n' "$(uf_style bold "$title")" "$(uf_style dim "$(uf_repeat '─' "${#title}")")"
}

# uf_success SUMMARY -- final success banner.
uf_success() {
  [ "${UF_QUIET:-0}" -eq 0 ] || return 0
  printf '\n%s %s\n' "$(uf_style green '✓')" "$(uf_style bold "$*")"
}

# uf_warn_banner SUMMARY -- final warning banner.
uf_warn_banner() {
  [ "${UF_QUIET:-0}" -eq 0 ] || return 0
  printf '\n%s %s\n' "$(uf_style yellow '⚠')" "$(uf_style bold "$*")"
}

# uf_log_tail [LINES] -- show where the log lives.
uf_log_tail() {
  [ -n "${UF_LOG_FILE:-}" ] && uf_info "Log: ${UF_LOG_FILE}"
}

# uf_summary_line -- print counts of skipped/changed settings.
uf_summary_line() {
  uf_debug "changed=${UF_CHANGED_COUNT} skipped=${UF_SKIP_COUNT} warnings=${UF_WARN_COUNT} errors=${UF_ERROR_COUNT}"
}
