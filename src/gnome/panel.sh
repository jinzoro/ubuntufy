# shellcheck shell=bash
# Top panel behaviour: clock, date, battery and calendar.

uf_panel_apply() {
  local clock_format
  clock_format="$(uf_conf panel.clock_format '')"

  if uf_conf_bool "panel.show_weekday" true; then
    uf_setting org.gnome.desktop.interface clock-show-weekday true "Clock weekday"
  fi
  if uf_conf_bool "panel.show_date" true; then
    uf_setting org.gnome.desktop.interface clock-show-date true "Clock date"
  fi
  uf_setting org.gnome.desktop.interface clock-show-seconds "$(uf_conf_bool panel.show_seconds false && printf true || printf false)" "Clock seconds"
  uf_setting org.gnome.desktop.interface show-battery-percentage "$(uf_conf_bool panel.show_battery_percentage true && printf true || printf false)" "Battery percentage"

  if [ -n "$clock_format" ]; then
    uf_setting org.gnome.desktop.interface clock-format "'${clock_format}'" "Clock format"
  fi

  if uf_conf_bool "notifications.show_in_lock_screen" true; then
    uf_setting org.gnome.desktop.notifications show-in-lock-screen true "Notifications on lock screen"
  fi

  # Ubuntu shows ISO week numbers in the calendar.
  uf_setting org.gnome.desktop.calendar show-weekdate true "Calendar week numbers"
  return 0
}
