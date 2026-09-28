#!/bin/bash

# Install herdr, which is not in nixpkgs, with its own installer (it installs
# to ~/.local/bin and updates itself with `herdr update`).
# See ./herdr.sh --help for options (--dry-run, --os).

# shellcheck source=../../../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../lib/common.sh"
init_script "$@"

HERDR_INSTALL_URL="https://herdr.dev/install.sh"

install_herdr() {
  if command -v herdr >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/herdr" ]]; then
    log_info "herdr is already installed"
    return 0
  fi

  log_info "Installing herdr from $HERDR_INSTALL_URL..."
  if is_dry_run; then
    log_dry "would run: curl -fsSL $HERDR_INSTALL_URL | sh"
    return 0
  fi
  if curl --proto '=https' --tlsv1.2 -fsSL "$HERDR_INSTALL_URL" | sh; then
    log_success "herdr installed"
  else
    log_error "Failed to install herdr"
    return 1
  fi
}

install_herdr
