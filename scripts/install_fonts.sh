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
    while IFS= read -r font || [[ -n "$font" ]]; do
        # Skip empty lines and comments
        if [[ -z "$font" || "$font" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Remove leading/trailing whitespace
        font=$(echo "$font" | xargs)
        
        # Ensure font name starts with "font-" for cask fonts
        if [[ ! "$font" =~ ^font- ]]; then
            font="font-$font"
        fi
        
        if brew list --cask | grep -q "^${font}$"; then
            log_info "$font is already installed"
        else
            log_info "Installing $font..."
            if brew install --cask "$font"; then
                log_success "$font installed successfully"
            else
                log_error "Failed to install $font"
            fi
        fi
    done < "$fonts_file"
    
    log_success "Fonts installation completed"
}

install_fonts 