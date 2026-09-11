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

# Add a custom APT repository (GPG key + sources.list.d entry) if not already present
# Args: name, key_url, apt_repo
setup_apt_repo() {
  local name="$1" key_url="$2" apt_repo="$3"
  local keyring="/usr/share/keyrings/${name}-archive-keyring.asc"
  local list_file="/etc/apt/sources.list.d/${name}.list"

  if [[ -f "$list_file" ]]; then
    log_info "APT repository for $name is already configured"
    return 0
  fi

  log_info "Adding APT repository for $name..."
  sudo curl -fsSLo "$keyring" "$key_url"
  echo "deb [signed-by=${keyring}] ${apt_repo}" | sudo tee "$list_file" >/dev/null
}

install_tools() {
  local tools_file="lists/tools.txt"

  if [[ ! -f "$tools_file" ]]; then
    log_error "Tools file not found: $tools_file"
    exit 1
  fi

  log_info "Installing command line tools from $tools_file..."

  # Refresh package metadata once up front
  log_info "Updating APT package lists..."
  sudo apt-get update

  # Collect missing tools, and any custom repos they need added first
  missing_tools=()
  repos_added=false
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Remove leading/trailing whitespace
    line=$(echo "$line" | xargs)

    local name key_url apt_repo package tool

    if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)(\|([^|]+))?$ ]]; then
      # Custom APT repo entry: name|key_url|apt_repo[|package]
      name="${BASH_REMATCH[1]}"
      key_url="${BASH_REMATCH[2]}"
      apt_repo="${BASH_REMATCH[3]}"
      package="${BASH_REMATCH[5]:-$name}"
      tool="$package"
    else
      tool="$line"
      name=""
    fi

    # Check if tool is already installed
    if command -v "${tool}" >/dev/null 2>&1 || dpkg -s "${tool}" >/dev/null 2>&1; then
      log_info "$tool is already installed"
    else
      if [[ -n "$name" ]]; then
        setup_apt_repo "$name" "$key_url" "$apt_repo"
        repos_added=true
      fi
      log_info "$tool will be installed via apt"
      missing_tools+=("$tool")
    fi
  done <"$tools_file"

  # A newly added repo's package metadata isn't visible until we refresh
  if [[ "$repos_added" == true ]]; then
    log_info "Updating APT package lists for newly added repositories..."
    sudo apt-get update
  fi

  # Install all missing tools in one apt call
  if [ ${#missing_tools[@]} -gt 0 ]; then
    log_info "Installing missing tools: ${missing_tools[*]}"
    sudo apt-get install -y "${missing_tools[@]}"
    log_success "Missing tools installed via apt"
  else
    log_success "All tools are already installed"
  fi
}

install_tools
