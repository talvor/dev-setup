#!/bin/bash

# Setup dotfiles using GNU Stow

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

setup_dotfiles() {
    local dotfiles_dir="dotfiles"
    
    if [[ ! -d "$dotfiles_dir" ]]; then
        log_warning "Dotfiles directory not found: $dotfiles_dir"
        log_info "Creating example dotfiles directory structure..."
        mkdir -p "$dotfiles_dir"
        return 0
    fi
    
    # Check if stow is installed
    if ! command -v stow &> /dev/null; then
        log_error "GNU Stow is not installed. Please install it first."
        log_info "Run: brew install stow"
        exit 1
    fi
    
    log_info "Setting up dotfiles using GNU Stow..."
    
    # Change to dotfiles directory
    cd "$dotfiles_dir" || exit 1
    
    # Stow each subdirectory
    for dir in */; do
        if [[ -d "$dir" ]]; then
            package_name=$(basename "$dir")
            log_info "Stowing $package_name..."
            
            if stow -t "$HOME" "$package_name"; then
                log_success "$package_name stowed successfully"
            else
                log_error "Failed to stow $package_name"
            fi
        fi
    done
    
    # Return to original directory
    cd - > /dev/null || exit 1
    
    log_success "Dotfiles setup completed"
    log_info "Your dotfiles are now symlinked from $dotfiles_dir to your home directory"
}

setup_dotfiles 