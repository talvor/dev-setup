#!/bin/bash

# Install Nix if needed and apply the Home Manager configuration of this OS
# (homeConfigurations.<os> in flake.nix: nix/ plus os/<os>/home.nix).
# See ./setup_home_manager.sh --help for options (--dry-run, --os).
#
# Nix comes from the official multi-user installer, with flakes enabled. The
# configuration is evaluated with --impure: it reads USER, HOME and
# DEV_SETUP_ROOT (this checkout, which the dotfile links point into).
#
# Any file in the way of a Home Manager link is renamed to <file>.hm-backup.
# Stow links are not removed: a machine still on Stow must run `stow -D` by hand
# before the first switch (README "Pop!_OS with Nix" gives the command).
# Otherwise the switch succeeds but keeps Stow's folded directory links (e.g.
# ~/.gnupg) and writes Home Manager links through them into dotfiles/.
#
# --dry-run installs nothing. When Nix is already installed it previews the
# switch with `home-manager switch --dry-run`, which builds into /nix/store but
# changes none of the files in $HOME (only Nix and Home Manager bookkeeping).

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
init_script "$@"

NIX_INSTALL_URL="https://nixos.org/nix/install"
NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
HM_BACKUP_EXT="hm-backup"
FLAKE="$DEV_SETUP_ROOT#$DEV_SETUP_OS"

# Flakes for every nix call below, even if nix.conf does not enable them
export NIX_CONFIG="extra-experimental-features = nix-command flakes${NIX_CONFIG:+
$NIX_CONFIG}"
# Read by flake.nix (--impure)
export DEV_SETUP_ROOT

# Make an installed Nix usable in this shell (right after installing it, it is
# not on the PATH yet). Fails if there is no Nix.
load_nix() {
  if ! command -v nix >/dev/null 2>&1 && [[ -r "$NIX_DAEMON_PROFILE" ]]; then
    # shellcheck disable=SC1090
    . "$NIX_DAEMON_PROFILE"
  fi
  command -v nix >/dev/null 2>&1
}

install_nix() {
  if load_nix; then
    log_info "Nix is already installed ($(nix --version))"
    return 0
  fi

  log_info "Installing Nix (official multi-user installer, flakes enabled)..."
  if is_dry_run; then
    log_dry "would run the installer from $NIX_INSTALL_URL with --daemon --yes --no-channel-add, adding 'experimental-features = nix-command flakes' to /etc/nix/nix.conf"
    return 0
  fi

  local tmp_dir
  tmp_dir=$(mktemp -d)
  echo "experimental-features = nix-command flakes" >"$tmp_dir/nix.conf"
  if ! curl --proto '=https' --tlsv1.2 -fsSL -o "$tmp_dir/install" "$NIX_INSTALL_URL" ||
    ! sh "$tmp_dir/install" --daemon --yes --no-channel-add --nix-extra-conf-file "$tmp_dir/nix.conf"; then
    rm -rf "$tmp_dir"
    log_error "Nix installation failed"
    exit 1
  fi
  rm -rf "$tmp_dir"

  if ! load_nix; then
    log_error "Nix was installed but is not usable in this shell. Open a new terminal and run this script again."
    exit 1
  fi
  log_success "Nix installed ($(nix --version))"
}

# The home-manager CLI pinned by flake.lock
home_manager() {
  nix run "$DEV_SETUP_ROOT#home-manager" -- "$@"
}

# Point at the stow -D a machine still on Stow needs before its first switch
log_stow_hint() {
  local dir pkgs=""
  for dir in "$DEV_SETUP_ROOT"/dotfiles/*/; do
    pkgs+=" $(basename "$dir")"
  done
  log_error "If this machine still has Stow links, remove them first: stow -D -d \"$DEV_SETUP_ROOT/dotfiles\" -t \"$HOME\"$pkgs (README \"Pop!_OS with Nix\")"
}

setup_home_manager() {
  if ! uses_home_manager; then
    log_error "$DEV_SETUP_OS is not set up with Home Manager (no os/$DEV_SETUP_OS/home.nix)"
    exit 1
  fi

  install_nix

  if is_dry_run; then
    if load_nix; then
      log_info "Previewing the Home Manager switch (builds into /nix/store, changes none of your files)."
      if ! home_manager switch --dry-run --impure --flake "$FLAKE" -b "$HM_BACKUP_EXT"; then
        log_error "The Home Manager preview failed"
        log_stow_hint
        exit 1
      fi
    else
      log_dry "would run: home-manager switch --impure --flake $FLAKE -b $HM_BACKUP_EXT"
    fi
    return 0
  fi

  # Build before touching $HOME, so a broken configuration changes nothing
  log_info "Building the Home Manager configuration for $DEV_SETUP_OS..."
  if ! nix build --no-link --impure "$DEV_SETUP_ROOT#homeConfigurations.$DEV_SETUP_OS.activationPackage"; then
    log_error "Building the Home Manager configuration failed; nothing was changed"
    exit 1
  fi

  log_info "Applying the Home Manager configuration (files in the way are renamed to *.$HM_BACKUP_EXT)..."
  if ! home_manager switch --impure --flake "$FLAKE" -b "$HM_BACKUP_EXT"; then
    log_error "Home Manager switch failed"
    log_stow_hint
    exit 1
  fi
  log_success "Home Manager configuration applied"

  if [[ -e "$HOME/.local/bin/herdr" ]]; then
    log_warning "$HOME/.local/bin/herdr (from the old herdr installer) comes before the Nix herdr on the PATH. Remove it with: rm ~/.local/bin/herdr"
  fi
}

setup_home_manager
