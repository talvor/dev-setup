#!/bin/bash

# Install CLI tools from URLs listed in lists/common/urls.txt and
# lists/<os>/urls.txt. Entries are name|url|method (script, binary, archive).
# See ./install_from_urls.sh --help for options (--dry-run, --os).
#
# NOTE: the actual install call in install_tools_from_urls is commented out (as
# it was on every branch), so this script only logs what it would install.
# Uncomment the install_from_url line there to enable installing.

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

TEMP_DIR=""

# Create temporary directory for downloads
create_temp_dir() {
  TEMP_DIR=$(mktemp -d)
  log_info "Created temporary directory: $TEMP_DIR"
}

# Clean up temporary directory
cleanup_temp_dir() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
    log_info "Cleaned up temporary directory"
  fi
}

# Install a tool from URL (runs in a subshell so the cd does not leak)
install_from_url() (
  local url="$1"
  local name="$2"
  local install_method="$3"

  log_info "Installing $name from $url..."

  if is_dry_run; then
    log_dry "would install $name from $url (method: $install_method)"
    return 0
  fi

  cd "$TEMP_DIR" || return 1

  case "$install_method" in
  "script")
    # Download and execute install script
    if curl -fsSL "$url" | bash; then
      log_success "$name installed successfully"
      return 0
    else
      log_error "Failed to install $name"
      return 1
    fi
    ;;
  "binary")
    # Download binary and install to /usr/local/bin
    local filename
    filename=$(basename "$url")
    local binary_name="$name"

    if curl -fsSL -o "$filename" "$url"; then
      chmod +x "$filename"
      if sudo mv "$filename" "/usr/local/bin/$binary_name"; then
        log_success "$name installed to /usr/local/bin/$binary_name"
        return 0
      else
        log_error "Failed to move $name to /usr/local/bin"
        return 1
      fi
    else
      log_error "Failed to download $name"
      return 1
    fi
    ;;
  "archive")
    # Download archive, extract, and install
    local filename
    filename=$(basename "$url")
    local binary_name="$name"

    if curl -fsSL -o "$filename" "$url"; then
      # Determine archive type and extract
      case "$filename" in
      *.tar.gz | *.tgz)
        tar -xzf "$filename"
        ;;
      *.tar.bz2)
        tar -xjf "$filename"
        ;;
      *.zip)
        unzip -q "$filename"
        ;;
      *)
        log_error "Unsupported archive format: $filename"
        return 1
        ;;
      esac

      # Find the binary and install it
      local binary_path
      binary_path=$(find . -name "$binary_name" -type f -perm -u+x | head -1)
      if [[ -n "$binary_path" ]]; then
        if sudo cp "$binary_path" "/usr/local/bin/$binary_name"; then
          sudo chmod +x "/usr/local/bin/$binary_name"
          log_success "$name installed to /usr/local/bin/$binary_name"
          return 0
        else
          log_error "Failed to install $name to /usr/local/bin"
          return 1
        fi
      else
        log_error "Could not find binary $binary_name in archive"
        return 1
      fi
    else
      log_error "Failed to download $name"
      return 1
    fi
    ;;
  *)
    log_error "Unknown install method: $install_method"
    return 1
    ;;
  esac
)

install_tools_from_urls() {
  check_lists urls || exit 1

  if ! is_dry_run; then
    create_temp_dir
    # Clean up on exit
    trap cleanup_temp_dir EXIT
  fi

  log_info "Installing CLI tools from URLs for $DEV_SETUP_OS..."

  local line
  while IFS= read -r line; do
    # Parse line format: name|url|method
    if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)$ ]]; then
      local name="${BASH_REMATCH[1]}"
      # shellcheck disable=SC2034 # only used by the commented-out install call
      local url="${BASH_REMATCH[2]}"
      # shellcheck disable=SC2034
      local method="${BASH_REMATCH[3]}"

      # Check if tool is already installed
      if command -v "$name" &>/dev/null; then
        log_info "$name is already installed"
      else
        log_info "Installing $name..."
        # install_from_url "$url" "$name" "$method"
      fi
    else
      log_warning "Invalid line format (should be name|url|method): $line"
    fi
  done < <(list_entries urls)

  log_success "URL-based tools installation completed"
}

install_tools_from_urls
