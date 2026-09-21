#!/bin/bash

# Install Nerd Fonts listed in lists/common/fonts.txt and lists/<os>/fonts.txt.
# The fonts are downloaded from the Nerd Fonts GitHub releases on every OS;
# the backend of the detected OS says where they go (PM_FONT_DIR).
# See ./install_fonts.sh --help for options (--dry-run, --os).

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

NERD_FONTS_VERSION="v3.4.0"

# Succeed if a font matching the given name is installed
font_installed() {
  local name="$1"

  if command -v fc-list >/dev/null 2>&1; then
    fc-list | grep -qi "$name"
  else
    # No fontconfig (stock macOS): look at the font files instead
    find "$PM_FONT_DIR" /Library/Fonts -iname "*${name}*" 2>/dev/null | grep -q .
  fi
}

download_font() {
  local name="$1"
  local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${name}.zip"

  log_info "Installing $name..."

  if is_dry_run; then
    log_dry "would download $font_url and copy its fonts to $PM_FONT_DIR"
    return 0
  fi

  local tmp_dir zip_file
  tmp_dir=$(mktemp -d)
  zip_file="$tmp_dir/${name}.zip"

  mkdir -p "$PM_FONT_DIR"

  log_info "Downloading $font_url..."
  if curl -fL -o "$zip_file" "$font_url"; then
    log_info "Extracting $zip_file..."
    unzip -o "$zip_file" -d "$tmp_dir"
    find "$tmp_dir" -type f \( -iname "*.ttf" -o -iname "*.otf" \) -exec cp {} "$PM_FONT_DIR" \;
    log_info "Cleaning up temporary files..."
    rm -rf "$tmp_dir"
    log_info "Refreshing font cache..."
    pm_fonts_refresh
    log_success "$name installed successfully"
  else
    log_error "Failed to download $font_url"
    rm -rf "$tmp_dir"
  fi
}

install_fonts() {
  check_lists fonts || exit 1

  log_info "Installing fonts for $DEV_SETUP_OS..."

  # Entries are "name" or "name|family". The family (when given) is what is
  # looked for to tell whether the font is already installed.
  local line name family check_name
  while IFS= read -r line; do
    IFS='|' read -r name family <<<"$line"
    name="${name%"${name##*[![:space:]]}"}"
    family="${family#"${family%%[![:space:]]*}"}"

    check_name="$name"
    if [[ -n "$family" ]]; then
      check_name="$family"
    fi

    if font_installed "$check_name"; then
      log_info "$check_name is already installed"
    else
      download_font "$name"
    fi
  done < <(list_entries fonts)

  log_success "Fonts installation completed"
}

install_fonts
