#!/bin/bash

# Install GUI applications from lists/common/apps.txt and lists/<os>/apps.txt
# using the app source of the detected OS (Flathub, Homebrew casks, pacman).
# See ./install_apps.sh --help for options (--dry-run, --os).

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

install_apps() {
  check_lists apps || exit 1

  pm_apps_prepare

  log_info "Installing GUI applications for $DEV_SETUP_OS..."

  local app
  while IFS= read -r app; do
    if pm_app_installed "$app"; then
      log_info "$app is already installed"
    else
      pm_app_install "$app"
    fi
  done < <(list_entries apps)

  log_success "GUI applications installation completed"
}

install_apps
