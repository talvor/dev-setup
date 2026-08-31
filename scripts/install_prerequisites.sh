#!/bin/bash

# Install prerequisites for Pop!_OS (Debian/Ubuntu-based)
# Ensures the tools the rest of the setup relies on are present.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

install_prerequisites() {
  if ! command -v apt-get >/dev/null 2>&1; then
    log_error "apt-get not found; this script targets Pop!_OS / Debian / Ubuntu"
    exit 1
  fi

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
  sudo apt-get update

  log_info "Installing prerequisites: ${packages[*]}"
  sudo apt-get install -y "${packages[@]}"

  # Flathub remote for GUI applications (install_apps.sh)
  if ! flatpak remotes --columns=name | grep -qx "flathub"; then
    log_info "Adding Flathub remote..."
    sudo flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  else
    log_info "Flathub remote already configured"
  fi

  log_success "Prerequisites installed"
}

install_prerequisites
