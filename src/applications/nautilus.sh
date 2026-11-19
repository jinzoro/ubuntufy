# shellcheck shell=bash
# GNOME Files (Nautilus) behaviour.

uf_nautilus_apply() {
  if ! uf_conf_bool "nautilus.enabled" true; then
    uf_skip "Nautilus configuration disabled."
    return 0
  fi

  # Ubuntu opens Files in list view with folders sorted first and the tree
  # sidebar available.
  uf_setting org.gnome.nautilus.preferences default-folder-viewer "'list-view'" "Files default view"
  uf_setting org.gnome.nautilus.preferences sort-directories-first true "Files: folders first"
  uf_setting org.gnome.nautilus.preferences show-create-link true "Files: create link action"
  uf_setting org.gnome.nautilus.preferences show-delete-permanently false "Files: delete permanently"

  uf_setting org.gnome.nautilus.list-view default-zoom-level "'small'" "Files list zoom"
  uf_setting org.gnome.nautilus.list-view use-tree-view false "Files tree view"
  uf_setting org.gnome.nautilus.list-view default-column-order \
    "['name', 'size', 'type', 'date_modified']" "Files column order"

  uf_setting org.gnome.nautilus.icon-view default-zoom-level "'standard'" "Files icon zoom"

  uf_debug "Bookmarks and the sidebar are left untouched so user bookmarks survive."
  return 0
}
