#!/bin/bash

# macOS backend: Homebrew formulae for command line tools, Homebrew casks for
# GUI applications. Sourced by lib/common.sh (init_script); see
# os/popos/backend.sh for the interface every backend implements.
#
# Tools list entries:
#   tool_name                - install from the default taps
#   tool_name#user/repo      - install from a GitHub tap
#   tool_name#user/repo#url  - install from a tap at a custom URL

# shellcheck disable=SC2034 # PM_* are read by the scripts that source this file
PM_INSTALL_CMD="brew install"
# shellcheck disable=SC2034
PM_FONT_DIR="$HOME/Library/Fonts"

# --- Tools (Homebrew formulae) ---
pm_tools_begin() {
  require_command brew "See https://brew.sh"
}

pm_tool_name() {
  echo "${1%%#*}"
}

pm_tool_installed() {
  command -v brew >/dev/null 2>&1 && brew list --formula | grep -qx "$1"
}

# Add the tap of a "tool#user/repo[#url]" entry
pm_tool_prepare() {
  [[ "$1" == *"#"* ]] || return 0

  local tool="${1%%#*}" tap_info="${1#*#}" tap_name tap_url=""
  if [[ "$tap_info" == *"#"* ]]; then
    tap_name="${tap_info%%#*}"
    tap_url="${tap_info##*#}"
    log_info "Processing $tool from custom tap: $tap_name with URL: $tap_url"
  else
    tap_name="$tap_info"
    log_info "Processing $tool from GitHub tap: $tap_name"
  fi

  if command -v brew >/dev/null 2>&1 && brew tap | grep -qx "$tap_name"; then
    log_info "Tap $tap_name already exists"
    return 0
  fi

  log_info "Adding tap: $tap_name"
  if [[ -n "$tap_url" ]]; then
    run brew tap "$tap_name" "$tap_url" || {
      log_error "Failed to add tap $tap_name from $tap_url"
      return 1
    }
  else
    run brew tap "$tap_name" || {
      log_error "Failed to add tap $tap_name from GitHub"
      return 1
    }
  fi
}

pm_tools_install() {
  local tool
  for tool in "$@"; do
    log_info "Installing $tool..."
    if run brew install "$tool"; then
      is_dry_run || log_success "$tool installed successfully"
    else
      log_error "Failed to install $tool"
    fi
  done
}

# --- Apps (Homebrew casks) ---
pm_apps_prepare() {
  require_command brew "See https://brew.sh"
}

pm_app_installed() {
  command -v brew >/dev/null 2>&1 && brew list --cask | grep -qx "$1"
}

pm_app_install() {
  log_info "Installing $1..."
  if run brew install --cask "$1"; then
    is_dry_run || log_success "$1 installed successfully"
  else
    log_error "Failed to install $1"
  fi
}

# --- Fonts ---
pm_fonts_refresh() {
  # macOS picks up fonts in ~/Library/Fonts by itself
  return 0
}
