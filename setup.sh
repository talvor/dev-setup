#!/bin/bash

# Dev Setup Script
# Automated setup of an OS using its native package manager and Stow.
#
# Usage: ./setup.sh [--dry-run] [--os <id>]
#   --dry-run  print what would be done without changing the system
#   --os <id>  skip auto-detection (fedora-atomic, popos, macos, omarchy)
# The same can be set with DEV_SETUP_DRY_RUN=1 and DEV_SETUP_OS=<id>.

set -e # Exit on any error

# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# Main setup function
main() {
  # Resolve the OS (unknown systems stop here) and the dry-run setting; both
  # are exported and picked up by the step scripts.
  init_script "$@"

  log_info "Starting Setup for $DEV_SETUP_OS..."
  log_newline

  local scripts="$DEV_SETUP_ROOT/scripts"

  # Run setup steps
  log_info "Step 1: Running OS prerequisites..."
  bash "$scripts/run_os_steps.sh" prerequisites
  log_newline

  log_info "Step 2: Installing command line tools..."
  bash "$scripts/install_tools.sh"
  log_newline

  log_info "Step 3: Installing applications..."
  bash "$scripts/install_apps.sh"
  log_newline

  log_info "Step 4: Installing fonts..."
  bash "$scripts/install_fonts.sh"
  log_newline

  log_info "Step 5: Installing tools from URLs..."
  bash "$scripts/install_from_urls.sh"
  log_newline

  log_info "Step 6: Running OS-specific install scripts..."
  bash "$scripts/run_os_steps.sh" install
  log_newline

  log_info "Step 7: Setting up dotfiles..."
  bash "$scripts/setup_dotfiles.sh"
  log_newline

  if is_dry_run; then
    log_success "Dry run completed; nothing was changed."
  else
    log_success "Setup completed successfully!"
    log_info "You may need to restart your terminal or source your shell configuration."
  fi
}

# Run main function
main "$@"
