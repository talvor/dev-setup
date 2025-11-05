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
        
        # Check if line contains a custom tap (format: tool#tap_url)
        if [[ "$line" == *"#"* ]]; then
            # Split on # to get tool name and tap info
            tool="${line%%#*}"
            tap_info="${line#*#}"
            
            # Check if tap_info contains another # (format: user/repo#url)
            if [[ "$tap_info" == *"#"* ]]; then
                # Format: tool#user/repo#url
                tap_name="${tap_info%%#*}"
                tap_url="${tap_info##*#}"
                log_info "Processing $tool from custom tap: $tap_name with URL: $tap_url"
            else
                # Format: tool#user/repo
                tap_name="$tap_info"
                tap_url=""
                log_info "Processing $tool from GitHub tap: $tap_name"
            fi
            
            # Add the tap first if not already added
            if ! brew tap | grep -q "^${tap_name}$"; then
                log_info "Adding tap: $tap_name"
                if [[ -n "$tap_url" ]]; then
                    # Add tap with custom URL
                    if brew tap "$tap_name" "$tap_url"; then
                        log_success "Tap $tap_name added successfully from $tap_url"
                    else
                        log_error "Failed to add tap $tap_name from $tap_url"
                        continue
                    fi
                else
                    # Add tap from GitHub
                    if brew tap "$tap_name"; then
                        log_success "Tap $tap_name added successfully from GitHub"
                    else
                        log_error "Failed to add tap $tap_name from GitHub"
                        continue
                    fi
                fi
            else
                log_info "Tap $tap_name already exists"
            fi
        else
            # Regular tool without custom tap
            tool="$line"
        fi
        
        # Check if tool is already installed
        if brew list --formula | grep -q "^${tool}$"; then
            log_info "$tool is already installed"
        else
            log_info "Installing $tool..."
            if brew install "$tool"; then
                log_success "$tool installed successfully"
            else
                log_error "Failed to install $tool"
            fi
        fi
    done < "$tools_file"
    
    log_success "Command line tools installation completed"
}

install_tools 