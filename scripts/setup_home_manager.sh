#!/bin/bash

# Install Nix if needed and apply the Home Manager configuration of this OS
# (homeConfigurations.<os> in flake.nix: nix/ plus os/<os>/home.nix).
# See ./setup_home_manager.sh --help for options (--dry-run, --os).
#
# Nix comes from the official multi-user installer, with flakes enabled. The
# configuration is evaluated with --impure: it reads USER, HOME and
# DEV_SETUP_ROOT (this checkout, which the dotfile links point into).
#
# Stow links into dotfiles/ are removed first, and any other file in the way of
# a Home Manager link is renamed to <file>.hm-backup.
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

# Stow links into dotfiles/ would be in the way of Home Manager's links.
# stow -D only removes links that point into the package, so this is safe to
# repeat.
remove_stow_links() {
  if ! command -v stow >/dev/null 2>&1; then
    log_info "Stow is not installed; no Stow links to remove"
    return 0
  fi

  local dir pkg output
  log_info "Removing Stow links into $DEV_SETUP_ROOT/dotfiles..."
  for dir in "$DEV_SETUP_ROOT"/dotfiles/*/; do
    pkg=$(basename "$dir")
    if is_dry_run; then
      log_dry "would run: stow -D -d $DEV_SETUP_ROOT/dotfiles -t $HOME $pkg"
      continue
    fi
    if ! output=$(stow -D -d "$DEV_SETUP_ROOT/dotfiles" -t "$HOME" "$pkg" 2>&1); then
      log_warning "Could not remove the Stow links of $pkg"
    fi
    # Once Home Manager has run, Stow notes every one of its links; drop that
    output=$(printf '%s\n' "$output" | grep -v '^Ignoring an absolute symlink' || true)
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output" >&2
    fi
  done
}

setup_home_manager() {
  if ! uses_home_manager; then
    log_error "$DEV_SETUP_OS is not set up with Home Manager (no os/$DEV_SETUP_OS/home.nix)"
    exit 1
  fi

  install_nix

  if is_dry_run; then
    remove_stow_links
    if load_nix; then
      log_info "Previewing the Home Manager switch (builds into /nix/store, changes none of your files)."
      log_info "The Stow links above are still in place, so the preview lists them as files it would back up."
      if ! home_manager switch --dry-run --impure --flake "$FLAKE" -b "$HM_BACKUP_EXT"; then
        log_error "The Home Manager preview failed"
        exit 1
      fi
    else
      log_dry "would run: home-manager switch --impure --flake $FLAKE -b $HM_BACKUP_EXT"
    fi
    return 0
  fi

  # Build before touching $HOME, so a broken configuration leaves the Stow
  # links alone
  log_info "Building the Home Manager configuration for $DEV_SETUP_OS..."
  if ! nix build --no-link --impure "$DEV_SETUP_ROOT#homeConfigurations.$DEV_SETUP_OS.activationPackage"; then
    log_error "Building the Home Manager configuration failed; nothing was changed"
    exit 1
  fi

  remove_stow_links

  log_info "Applying the Home Manager configuration (files in the way are renamed to *.$HM_BACKUP_EXT)..."
  if ! home_manager switch --impure --flake "$FLAKE" -b "$HM_BACKUP_EXT"; then
    log_error "Home Manager switch failed. To put the Stow links back meanwhile, run ./scripts/setup_dotfiles.sh"
    exit 1
  fi
  log_success "Home Manager configuration applied"

  if [[ -e "$HOME/.local/bin/herdr" ]]; then
    log_warning "$HOME/.local/bin/herdr (from the old herdr installer) comes before the Nix herdr on the PATH. Remove it with: rm ~/.local/bin/herdr"
  fi
}

setup_home_manager
