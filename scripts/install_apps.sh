#!/bin/bash

# Install GUI applications

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

install_apps() {
  local apps_file="lists/apps.txt"

  if [[ ! -f "$apps_file" ]]; then
    log_error "Apps file not found: $apps_file"
    exit 1
  fi

  if ! command -v flatpak >/dev/null 2>&1; then
    log_error "flatpak is not installed. Run ./scripts/install_prerequisites.sh first."
    exit 1
  fi

  # Ensure the Flathub remote is configured (system-wide)
  if ! flatpak remotes --columns=name | grep -qx "flathub"; then
    log_info "Adding Flathub remote..."
    sudo flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi

  log_info "Installing GUI applications from $apps_file..."

  # Read apps from file and install
  while IFS= read -r app || [[ -n "$app" ]]; do
    # Skip empty lines and comments
    if [[ -z "$app" || "$app" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Remove leading/trailing whitespace
    app=$(echo "$app" | xargs)

    # Check if app is already installed via Flatpak
    if flatpak list --columns=application | grep -qx "$app"; then
      log_info "$app is already installed via Flatpak"
    else
      log_info "Installing $app via Flatpak..."
      flatpak install -y flathub "$app"
    fi
  done <"$apps_file"

  log_success "GUI applications installation completed"
}

install_apps
