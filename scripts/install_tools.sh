#!/bin/bash

# Install command line tools from lists/common/tools.txt and
# lists/<os>/tools.txt using the package manager of the detected OS.
# See ./install_tools.sh --help for options (--dry-run, --os).

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

install_tools() {
  check_lists tools || exit 1

  log_info "Installing command line tools for $DEV_SETUP_OS..."

  pm_tools_begin

  # Collect missing tools, and add any repo they need first
  local missing_tools=() line tool
  while IFS= read -r line; do
    tool="$(pm_tool_name "$line")"

    if pm_tool_installed "$tool"; then
      log_info "$tool is already installed"
    elif pm_tool_prepare "$line"; then
      log_info "$tool will be installed"
      missing_tools+=("$tool")
    else
      log_error "Skipping $tool"
    fi
  done < <(list_entries tools)

  # Install all missing tools in one call
  if [ ${#missing_tools[@]} -gt 0 ]; then
    pm_tools_install "${missing_tools[@]}"
  else
    log_success "All tools are already installed"
  fi
}

install_tools
