#!/bin/bash

# Install CLI tools from URLs

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

# Install a tool from URL
install_from_url() {
  local url="$1"
  local name="$2"
  local install_method="$3"

  log_info "Installing $name from $url..."

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
    local filename=$(basename "$url")
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
    local filename=$(basename "$url")
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
      local binary_path=$(find . -name "$binary_name" -type f -executable | head -1)
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
}

install_tools_from_urls() {
  local urls_file="lists/urls.txt"

  if [[ ! -f "$urls_file" ]]; then
    log_error "URLs file not found: $urls_file"
    exit 1
  fi

  # Create temporary directory
  create_temp_dir

  # Set trap to clean up on exit
  trap cleanup_temp_dir EXIT

  log_info "Installing CLI tools from URLs listed in $urls_file..."

  # Read URLs from file and install
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Remove leading/trailing whitespace
    line=$(echo "$line" | xargs)

    # Parse line format: name|url|method
    if [[ "$line" =~ ^([^|]+)\|([^|]+)\|([^|]+)$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local url="${BASH_REMATCH[2]}"
      local method="${BASH_REMATCH[3]}"

      # Check if tool is already installed
      if command -v "$name" &>/dev/null; then
        log_info "$name is already installed"
      else
        log_info "Installing $tool..."
        # install_from_url "$url" "$name" "$method"
      fi
    else
      log_warning "Invalid line format (should be name|url|method): $line"
    fi
  done <"$urls_file"

  log_success "URL-based tools installation completed"
}

install_tools_from_urls

