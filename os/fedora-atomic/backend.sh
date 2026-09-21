#!/bin/bash

# Fedora Atomic (Silverblue, Kinoite, CoreOS, ...) backend: rpm-ostree for
# command line tools, Flatpak for GUI applications.
# Sourced by lib/common.sh (init_script); see os/popos/backend.sh for the
# interface every backend implements.

# shellcheck source=../../lib/flatpak.sh
. "$DEV_SETUP_ROOT/lib/flatpak.sh"

# shellcheck disable=SC2034 # PM_* are read by the scripts that source this file
PM_INSTALL_CMD="rpm-ostree install"
# shellcheck disable=SC2034
PM_FONT_DIR="$HOME/.local/share/fonts"

# --- Tools (rpm-ostree) ---
pm_tools_begin() {
  require_command rpm-ostree
}

pm_tool_name() {
  echo "$1"
}

pm_tool_installed() {
  command -v "$1" >/dev/null 2>&1 || rpm -q "$1" >/dev/null 2>&1
}

pm_tool_prepare() {
  return 0
}

pm_tools_install() {
  log_info "Installing missing tools: $*"
  run rpm-ostree install "$@"
  is_dry_run || log_success "Missing tools layered with rpm-ostree (reboot to use them)"
}

# --- Apps (Flatpak) ---
pm_apps_prepare() {
  flatpak_prepare
}

pm_app_installed() {
  flatpak_app_installed "$1"
}

pm_app_install() {
  flatpak_app_install "$1"
}

# --- Fonts ---
pm_fonts_refresh() {
  run fc-cache -f "$PM_FONT_DIR"
}
