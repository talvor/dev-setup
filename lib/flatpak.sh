#!/bin/bash

# Flatpak helpers shared by the backends that install GUI apps from Flathub
# (fedora-atomic and popos). Source lib/common.sh first.

flatpak_prepare() {
  require_command flatpak "Install it first (see the OS prerequisites step)."

  # Ensure the Flathub remote is configured (system-wide)
  if command -v flatpak >/dev/null 2>&1 && flatpak remotes --columns=name | grep -qx "flathub"; then
    return 0
  fi
  log_info "Adding Flathub remote..."
  run sudo flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
}

flatpak_app_installed() {
  command -v flatpak >/dev/null 2>&1 && flatpak list --columns=application | grep -qx "$1"
}

flatpak_app_install() {
  log_info "Installing $1 via Flatpak..."
  run flatpak install -y flathub "$1"
}
