# shellcheck shell=bash
# Wallpaper handling.
#
# Ubuntuify never replaces a user's wallpaper without a choice. The shipped
# Ubuntu-style wallpaper is generated locally (original artwork, no Ubuntu
# assets are redistributed).

UF_ARTWORK="${UF_SRC}/core/artwork.py"

# uf_wallpaper_uri PATH -- file:// URI for GSettings.
uf_wallpaper_uri() {
  python3 - "$1" <<'PY'
import pathlib
import sys

print(pathlib.Path(sys.argv[1]).expanduser().resolve().as_uri())
PY
}

# uf_wallpaper_generate DARK -- generate the project wallpaper, print its path.
uf_wallpaper_generate() {
  local dark="$1" width height scheme path
  width="$(uf_conf_int 'wallpaper.width' 2560 1280 7680)"
  height="$(uf_conf_int 'wallpaper.height' 1440 720 4320)"
  if [ "$dark" -eq 1 ]; then scheme="dark"; else scheme="light"; fi
  path="${UF_WALLPAPER_DIR}/ubuntuify-${scheme}-${width}x${height}.png"

  if [ -s "$path" ]; then
    uf_debug "Wallpaper already generated: ${path}"
    printf '%s\n' "$path"
    return 0
  fi
  if [ "$UF_DRY_RUN" -eq 1 ]; then
    uf_dry "Would generate wallpaper ${path}"
    printf '%s\n' "$path"
    return 0
  fi
  mkdir -p "$UF_WALLPAPER_DIR"
  if ! python3 "$UF_ARTWORK" wallpaper "$path" "$width" "$height" "$scheme"; then
    uf_warn "Could not generate the Ubuntu-style wallpaper."
    return 1
  fi
  uf_ok "Generated Ubuntu-style wallpaper"
  printf '%s\n' "$path"
}

# uf_wallpaper_choose -- interactive choice. Prints a path or "keep".
uf_wallpaper_choose() {
  local choice path
  choice="$(uf_menu "Wallpaper" \
    "Use Ubuntu-style wallpaper" \
    "Keep current wallpaper" \
    "Choose a picture" || true)"
  case "$choice" in
    "Use Ubuntu-style wallpaper")
      printf 'ubuntu-default\n'
      ;;
    "Choose a picture")
      path="$(uf_ask 'Path to an image file:')"
      if [ -n "$path" ] && [ -f "$path" ]; then
        printf '%s\n' "$path"
      else
        uf_warn "No readable image selected; keeping the current wallpaper."
        printf 'keep\n'
      fi
      ;;
    *)
      printf 'keep\n'
      ;;
  esac
}

# uf_wallpaper_set PATH -- write background settings.
uf_wallpaper_set() {
  local path="$1" uri dark=0 primary="#2c001e"
  uri="$(uf_wallpaper_uri "$path")"
  uf_theme_is_dark && dark=1
  [ "$dark" -eq 0 ] && primary="#faf7f2"

  uf_setting org.gnome.desktop.background picture-uri "'${uri}'" "Desktop wallpaper"
  uf_setting org.gnome.desktop.background picture-uri-dark "'${uri}'" "Desktop wallpaper (dark)"
  uf_setting org.gnome.desktop.background picture-options "'zoom'" "Wallpaper scaling"
  uf_setting org.gnome.desktop.background primary-color "'${primary}'" "Wallpaper fallback colour"
  uf_setting org.gnome.desktop.screensaver picture-uri "'${uri}'" "Lock screen wallpaper"
  uf_state_set "wallpaper" "$path"
}

# uf_wallpaper_apply -- resolve the configured mode and apply it.
uf_wallpaper_apply() {
  local mode path dark=0
  uf_theme_is_dark && dark=1

  mode="$(uf_conf wallpaper.mode ask)"
  if [ "$mode" = "ask" ]; then
    if [ -t 0 ] && [ "$UF_ASSUME_YES" -eq 0 ]; then
      mode="$(uf_wallpaper_choose)"
    else
      uf_info "Keeping the current wallpaper. Set wallpaper.mode=ubuntu-default to use the Ubuntu-style wallpaper."
      mode="keep"
    fi
  fi

  case "$mode" in
    keep)
      uf_ok "Keeping the current wallpaper"
      return 0
      ;;
    ubuntu-default)
      if ! path="$(uf_wallpaper_generate "$dark")"; then
        return 1
      fi
      ;;
    path)
      path="$(uf_conf wallpaper.path '')"
      if [ -z "$path" ] || [ ! -f "$path" ]; then
        uf_warn "wallpaper.path is not set or not a file; keeping the current wallpaper."
        return 2
      fi
      ;;
    /*)
      if [ ! -f "$mode" ]; then
        uf_warn "Wallpaper file not found: ${mode}; keeping the current wallpaper."
        return 2
      fi
      path="$mode"
      ;;
    *)
      uf_warn "Unknown wallpaper mode '${mode}'; keeping the current wallpaper."
      return 2
      ;;
  esac

  uf_wallpaper_set "$path"
  return 0
}
