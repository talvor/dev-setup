#!/bin/bash

# Omarchy (Arch Linux) backend: pacman for command line tools and GUI
# applications. Sourced by lib/common.sh (init_script); see
# os/popos/backend.sh for the interface every backend implements.
#
# UNTESTED: written without access to an Omarchy machine. Run
# `./setup.sh --os omarchy --dry-run` first and check the package names in
# lists/omarchy/ before relying on it.
#
# Only the official repositories are used. AUR packages are not supported.
# Packages are never installed with -y/-Sy on their own: that would refresh
# the package database without upgrading and risk a partial upgrade on Arch.

# shellcheck disable=SC2034 # PM_* are read by the scripts that source this file
PM_INSTALL_CMD="sudo pacman -S --needed"
# shellcheck disable=SC2034
PM_FONT_DIR="$HOME/.local/share/fonts"

pacman_installed() {
  command -v pacman >/dev/null 2>&1 && pacman -Qi "$1" >/dev/null 2>&1
}

pacman_install() {
  run sudo pacman -S --needed --noconfirm "$@"
}

# --- Tools (pacman) ---
pm_tools_begin() {
  require_command pacman
}

pm_tool_name() {
  echo "$1"
}

pm_tool_installed() {
  command -v "$1" >/dev/null 2>&1 || pacman_installed "$1"
}

pm_tool_prepare() {
  return 0
}

pm_tools_install() {
  log_info "Installing missing tools: $*"
  pacman_install "$@"
  is_dry_run || log_success "Missing tools installed via pacman"
}

# --- Apps (pacman) ---
pm_apps_prepare() {
  require_command pacman
}

pm_app_installed() {
  pacman_installed "$1"
}

pm_app_install() {
  log_info "Installing $1 via pacman..."
  pacman_install "$1"
}

# --- Fonts ---
pm_fonts_refresh() {
  run fc-cache -f "$PM_FONT_DIR"
}
