#!/bin/bash

# Pop!_OS system step: everything that needs root (apt). It runs before Nix
# and Home Manager (os/popos/home.nix), which manage everything else.
# See ./prerequisites.sh --help for options (--dry-run, --os).

# shellcheck source=../../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
init_script "$@"

install_prerequisites() {
  require_command apt-get "This script targets Pop!_OS / Debian / Ubuntu"

  # Packages that stay with apt:
  #   curl, ca-certificates, xz-utils, git - the Nix installer and flakes
  #   flatpak    - host Flatpak (portals, desktop integration) for the apps
  #                nix-flatpak installs
  #   fontconfig - font cache for the fonts Home Manager installs
  #   zsh        - login shell, must be in /etc/shells
  #   alacritty  - GUI app that is not on Flathub (Nix GUI apps lack the host
  #                graphics drivers)
  #   stow       - the fallback scripts/setup_dotfiles.sh
  #   build-essential - the host C toolchain, for building against system
  #                libraries
  local packages=(
    build-essential
    ca-certificates
    curl
    wget
    git
    xz-utils
    unzip
    fontconfig
    flatpak
    zsh
  )

  # GUI apps from custom APT repositories (lists/popos/tools.txt format)
  local repo_tools=(
    "claude-desktop|https://downloads.claude.ai/claude-desktop/key.asc|https://downloads.claude.ai/claude-desktop/apt/stable stable main"
  )

  local entry
  for entry in "${repo_tools[@]}"; do
    if pm_tool_prepare "$entry"; then
      packages+=("$(pm_tool_name "$entry")")
    fi
  done

  log_info "Updating APT package lists..."
  run sudo apt-get update

  log_info "Installing prerequisites: ${packages[*]}"
  run sudo apt-get install -y "${packages[@]}"

  # System-wide Flathub remote, for scripts/install_apps.sh. nix-flatpak adds
  # its own per-user one.
  if command -v flatpak >/dev/null 2>&1 && flatpak remotes --columns=name | grep -qx "flathub"; then
    log_info "Flathub remote already configured"
  else
    log_info "Adding Flathub remote..."
    run sudo flatpak remote-add --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi

  log_success "Prerequisites installed"
}

install_prerequisites
