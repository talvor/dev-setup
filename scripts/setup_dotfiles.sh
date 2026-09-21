#!/bin/bash

# Setup dotfiles using GNU Stow
# See ./setup_dotfiles.sh --help for options (--dry-run, --os).
#
# Every package under dotfiles/ is stowed on every OS. The zsh package holds
# one file per OS in ~/.zsh; ~/.zshrc sources the right one at shell start.

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

  log_info "Setting up dotfiles using GNU Stow..."

  # Stow each subdirectory
  local dir package_name
  for dir in "$dotfiles_dir"/*/; do
    if [[ -d "$dir" ]]; then
      package_name=$(basename "$dir")
      log_info "Stowing $package_name..."

      if is_dry_run; then
        log_dry "would run: stow -d $dotfiles_dir -t $HOME $package_name"
      elif stow -d "$dotfiles_dir" -t "$HOME" "$package_name"; then
        log_success "$package_name stowed successfully"
      else
        log_error "Failed to stow $package_name"
      fi
    fi
  done

  log_success "Dotfiles setup completed"
  log_info "Your dotfiles are now symlinked from $dotfiles_dir to your home directory"
}

setup_dotfiles
