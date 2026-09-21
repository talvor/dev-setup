#!/bin/bash

# Install prerequisites for Pop!_OS (Debian/Ubuntu-based)
# Ensures the tools the rest of the setup relies on are present.
# See ./prerequisites.sh --help for options (--dry-run, --os).

# shellcheck source=../../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
init_script "$@"

install_prerequisites() {
  require_command apt-get "This script targets Pop!_OS / Debian / Ubuntu"

  # Packages needed by setup.sh and the scripts it calls
  local packages=(
    build-essential
    ca-certificates
    curl
    wget
    git
    unzip
    stow
    fontconfig
    flatpak
  )

  log_info "Updating APT package lists..."
  run sudo apt-get update

  log_info "Installing prerequisites: ${packages[*]}"
  run sudo apt-get install -y "${packages[@]}"

  # Flathub remote for GUI applications (install_apps.sh)
  if command -v flatpak >/dev/null 2>&1 && flatpak remotes --columns=name | grep -qx "flathub"; then
    log_info "Flathub remote already configured"
  else
    log_info "Adding Flathub remote..."
    run sudo flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi

  log_success "Prerequisites installed"
}

install_prerequisites
