# shellcheck shell=bash
# Notification defaults.

uf_notifications_apply() {
  if uf_conf_bool "notifications.show_in_lock_screen" true; then
    uf_setting org.gnome.desktop.notifications show-in-lock-screen true "Notifications on lock screen"
  fi
  uf_setting org.gnome.desktop.notifications show-banners true "Notification banners"
  return 0
}
