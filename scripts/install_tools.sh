#!/bin/bash

# Install command line tools from file

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

install_tools() {
  local tools_file="lists/tools.txt"

  if [[ ! -f "$tools_file" ]]; then
    log_error "Tools file not found: $tools_file"
    exit 1
  fi

  log_info "Installing command line tools from $tools_file..."

  # Read tools from file and install
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Remove leading/trailing whitespace
    line=$(echo "$line" | xargs)

    tool="$line"

    # Check if tool is already installed
    if command -v "${tool}" >/dev/null 2>&1; then
      log_info "$tool is already installed"
    else
      log_info "Installing $tool..."
    fi
  done <"$tools_file"

  log_success "Command line tools installation completed"
}

install_tools

