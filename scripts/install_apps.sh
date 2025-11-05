#!/bin/bash

# Install GUI applications from file using Homebrew Cask

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

install_apps() {
    local apps_file="lists/apps.txt"
    
    if [[ ! -f "$apps_file" ]]; then
        log_error "Apps file not found: $apps_file"
        exit 1
    fi
    
    log_info "Installing GUI applications from $apps_file..."
    
    # Read apps from file and install
    while IFS= read -r app || [[ -n "$app" ]]; do
        # Skip empty lines and comments
        if [[ -z "$app" || "$app" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Remove leading/trailing whitespace
        app=$(echo "$app" | xargs)
        
        if brew list --cask | grep -q "^${app}$"; then
            log_info "$app is already installed"
        else
            log_info "Installing $app..."
            if brew install --cask "$app"; then
                log_success "$app installed successfully"
            else
                log_error "Failed to install $app"
            fi
        fi
    done < "$apps_file"
    
    log_success "GUI applications installation completed"
}

install_apps 