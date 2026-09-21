#!/bin/bash

# Run the extra steps that belong to one OS only (not lists):
#   prerequisites  - os/<os>/prerequisites.sh, runs before anything is installed
#   install        - os/<os>/install_scripts/*.sh, runs after the lists
#
# Usage: run_os_steps.sh <prerequisites|install> [--dry-run] [--os <id>]

step="${1:-}"
if [[ "$step" != "prerequisites" && "$step" != "install" ]]; then
  echo "Usage: $0 <prerequisites|install> [--dry-run] [--os <id>]" >&2
  exit 2
fi
shift

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

os_dir="$DEV_SETUP_ROOT/os/$DEV_SETUP_OS"

case "$step" in
prerequisites)
  if [[ -f "$os_dir/prerequisites.sh" ]]; then
    log_info "Running prerequisites for $DEV_SETUP_OS..."
    bash "$os_dir/prerequisites.sh"
  else
    log_info "No prerequisites for $DEV_SETUP_OS"
  fi
  ;;
install)
  found=false
  for script in "$os_dir"/install_scripts/*.sh; do
    if [[ -f "$script" ]]; then
      found=true
      log_info "Running $(basename "$script")..."
      bash "$script"
    fi
  done
  if [[ "$found" == false ]]; then
    log_info "No extra install scripts for $DEV_SETUP_OS"
  fi
  ;;
esac
