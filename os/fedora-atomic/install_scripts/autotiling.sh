#!/bin/bash

# Install autotiling (sway). Runs as an extra step of the fedora-atomic setup.
# See ./autotiling.sh --help for options (--dry-run, --os).

# shellcheck source=../../../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../lib/common.sh"
init_script "$@"

INSTALL_URL="https://raw.githubusercontent.com/nwg-piotr/autotiling/refs/heads/master/autotiling/main.py"
BINARY_PATH="/usr/local/bin/autotiling"

if [ ! -f "$BINARY_PATH" ]; then
  run sudo curl -fsSL "$INSTALL_URL" -o "$BINARY_PATH"
  run sudo chown root:root "$BINARY_PATH"
  run sudo chmod +x "$BINARY_PATH"
  is_dry_run || log_success "autotiling installed to $BINARY_PATH"
else
  log_info "autotiling is already installed at $BINARY_PATH"
fi
