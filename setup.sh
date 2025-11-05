#!/bin/bash

# Dev Setup Script
# Automated setup OS using native package manager and Stow

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if script is run on macOS
check_os() {
  # if [[ "$OSTYPE" != "darwin"* ]]; then
  #   log_error "This script is designed for macOS only"
  #   exit 1
  # fi
  log_info "Checking OS compatibility..."
}

# Main setup function
main() {
  log_info "Starting Setup..."

  # Check OS compatibility
  check_os

  # Make all scripts executable
  chmod +x scripts/*.sh

  # Run setup steps
  log_info "Step 1: Installing Prerequisites..."
  if [ -f ./scripts/install_prerequisites.sh ]; then
    ./scripts/install_prerequisites.sh
  else
    log_warning "Prerequisites script not found, skipping step 1."
  fi

  log_info "Step 2: Installing command line tools..."
  ./scripts/install_tools.sh

  log_info "Step 3: Installing applications..."
  ./scripts/install_apps.sh

  log_info "Step 4: Installing fonts..."
  ./scripts/install_fonts.sh

  log_info "Step 5: Installing tools from URLs..."
  ./scripts/install_from_urls.sh

  log_info "Step 6: Setting up dotfiles..."
  ./scripts/setup_dotfiles.sh

  log_success "Setup completed successfully!"
  log_info "You may need to restart your terminal or source your shell configuration."
}

# Run main function
main "$@"
