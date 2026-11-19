# shellcheck shell=bash
# GNOME-level power preferences only.
#
# Ubuntuify never disables power-profiles-daemon, thermald or logind, and never
# changes Fedora's suspend/idle policy beyond what the user configures.

uf_power_apply() {
  uf_setting org.gnome.settings-daemon.plugins.power power-button-action \
    "'$(uf_conf power.button_action interactive)'" "Power button action"
  return 0
}
