#!/bin/bash

# Install fonts from file using Homebrew

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

install_fonts() {
  local fonts_file="lists/fonts.txt"

  if [[ ! -f "$fonts_file" ]]; then
    log_error "Fonts file not found: $fonts_file"
    exit 1
  fi

  log_info "Installing fonts from $fonts_file..."

  # Read fonts from file and install
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Remove leading/trailing whitespace
    line=$(echo "$line" | xargs)

    # Parse name and optional family
    IFS='|' read -r name family <<<"$line"
    name=$(echo "$name" | xargs)
    family=$(echo "$family" | xargs)

    # Use family for existence check if provided, otherwise use name
    check_name="$name"
    if [[ -n "$family" ]]; then
      check_name="$family"
    fi

    # Check if font is already installed
    if fc-list | grep -qi "$check_name"; then
      log_info "$check_name is already installed"
    else
      log_info "Installing $name..."
      FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/${name}.zip"
      TMP_DIR=$(mktemp -d)
      ZIP_FILE="$TMP_DIR/${name}.zip"
      FONT_DEST="$HOME/.local/share/fonts"

      mkdir -p "$FONT_DEST"

      log_info "Downloading $FONT_URL..."
      if curl -L -o "$ZIP_FILE" "$FONT_URL"; then
        log_info "Extracting $ZIP_FILE..."
        unzip -o "$ZIP_FILE" -d "$TMP_DIR"
        find "$TMP_DIR" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp {} "$FONT_DEST" \;
        log_info "Cleaning up temporary files..."
        rm -rf "$TMP_DIR"
        log_info "Refreshing font cache..."
        fc-cache -f "$FONT_DEST"
        log_success "$name installed successfully"
      else
        log_error "Failed to download $FONT_URL"
        rm -rf "$TMP_DIR"
      fi
    fi
  done <"$fonts_file"

  log_success "Fonts installation completed"
}

install_fonts
