#!/bin/bash

# Setup dotfiles using GNU Stow
# See ./setup_dotfiles.sh --help for options (--dry-run, --os).
#
# Stows the packages (directories under dotfiles/) listed in
# lists/<os>/dotfiles.txt, one name per line. There is no common list: each OS
# names every package it wants. A listed package without a dotfiles/<name>
# directory is skipped with a warning; a missing list file is an error.
# The zsh package holds one file per OS in ~/.zsh; ~/.zshrc sources the right
# one at shell start.

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

setup_dotfiles() {
  local dotfiles_dir="$DEV_SETUP_ROOT/dotfiles"

  if [[ ! -d "$dotfiles_dir" ]]; then
    log_warning "Dotfiles directory not found: $dotfiles_dir"
    log_info "Creating example dotfiles directory structure..."
    run mkdir -p "$dotfiles_dir"
    return 0
  fi

  # Check if stow is installed
  if ! command -v stow &>/dev/null; then
    if is_dry_run; then
      log_warning "GNU Stow is not installed; continuing because this is a dry run"
    else
      log_error "GNU Stow is not installed. Please install it first."
      log_info "Run: $PM_INSTALL_CMD stow"
      exit 1
    fi
  fi

  local list_file="$DEV_SETUP_ROOT/lists/$DEV_SETUP_OS/dotfiles.txt"
  if [[ ! -f "$list_file" ]]; then
    log_error "Dotfiles list not found: $list_file"
    exit 1
  fi

  log_info "Setting up dotfiles for $DEV_SETUP_OS using GNU Stow..."

  # Stow each listed package
  local package_name
  while IFS= read -r package_name; do
    if [[ ! -d "$dotfiles_dir/$package_name" ]]; then
      log_warning "Skipping $package_name: $dotfiles_dir/$package_name not found"
      continue
    fi
    log_info "Stowing $package_name..."

    if is_dry_run; then
      log_dry "would run: stow -d $dotfiles_dir -t $HOME $package_name"
    elif stow -d "$dotfiles_dir" -t "$HOME" "$package_name"; then
      log_success "$package_name stowed successfully"
    else
      log_error "Failed to stow $package_name"
    fi
  done < <(list_file_entries "$list_file")

  log_success "Dotfiles setup completed"
  log_info "Your dotfiles are now symlinked from $dotfiles_dir to your home directory"
}

setup_dotfiles
