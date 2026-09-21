#!/bin/bash

# Pop!_OS backend: apt for command line tools, Flatpak for GUI applications.
# Sourced by lib/common.sh (init_script).
#
# Every backend implements:
#   PM_INSTALL_CMD           how to install a package by hand (used in hints)
#   PM_FONT_DIR              where Nerd Fonts are unpacked
#   pm_tools_begin           run once before the tools list is read
#   pm_tool_name LINE        package name of a tools list entry
#   pm_tool_installed NAME   succeed if the tool is already installed
#   pm_tool_prepare LINE     add a repo/tap the entry needs (fail to skip it)
#   pm_tools_install NAME... install the missing tools
#   pm_apps_prepare          run once before the apps list is read
#   pm_app_installed ID      succeed if the app is already installed
#   pm_app_install ID        install one app
#   pm_fonts_refresh         refresh the font cache after fonts were added

# shellcheck source=../../lib/flatpak.sh
. "$DEV_SETUP_ROOT/lib/flatpak.sh"

# shellcheck disable=SC2034 # PM_* are read by the scripts that source this file
PM_INSTALL_CMD="sudo apt-get install -y"
# shellcheck disable=SC2034
PM_FONT_DIR="$HOME/.local/share/fonts"

APT_REPOS_ADDED=false

# Add a custom APT repository (GPG key + sources.list.d entry) if not already present
# Args: name, key_url, apt_repo
setup_apt_repo() {
  local name="$1" key_url="$2" apt_repo="$3"
  local keyring="/usr/share/keyrings/${name}-archive-keyring.asc"
  local list_file="/etc/apt/sources.list.d/${name}.list"

  if [[ -f "$list_file" ]]; then
    log_info "APT repository for $name is already configured"
    return 0
  fi

  log_info "Adding APT repository for $name..."
  if is_dry_run; then
    log_dry "would download $key_url to $keyring and write $list_file"
    return 0
  fi
  if ! sudo curl -fsSLo "$keyring" "$key_url" ||
    ! echo "deb [signed-by=${keyring}] ${apt_repo}" | sudo tee "$list_file" >/dev/null; then
    sudo rm -f "$keyring" "$list_file"
    log_error "Failed to add APT repository for $name"
    return 1
  fi
}

# --- Tools (apt) ---
pm_tools_begin() {
  require_command apt-get

  # Refresh package metadata once up front
  log_info "Updating APT package lists..."
  run sudo apt-get update
}

# Entries are either "package" or "name|key_url|apt_repo[|package]"
pm_tool_name() {
  if [[ "$1" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|([^|]+))?$ ]]; then
    echo "${BASH_REMATCH[5]:-${BASH_REMATCH[1]}}"
  else
    echo "$1"
  fi
}

pm_tool_installed() {
  command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1
}

pm_tool_prepare() {
  if [[ "$1" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|([^|]+))?$ ]]; then
    setup_apt_repo "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" || return 1
    APT_REPOS_ADDED=true
  fi
}

pm_tools_install() {
  # A newly added repo's package metadata isn't visible until we refresh
  if [[ "$APT_REPOS_ADDED" == true ]]; then
    log_info "Updating APT package lists for newly added repositories..."
    run sudo apt-get update
  fi

  log_info "Installing missing tools: $*"
  run sudo apt-get install -y "$@"
  is_dry_run || log_success "Missing tools installed via apt"
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
