#!/bin/bash

# Install Nix if needed and apply the Home Manager configuration of this OS
# (homeConfigurations.<os> in flake.nix: nix/ plus os/<os>/home.nix).
# See ./setup_home_manager.sh --help for options (--dry-run, --os).
#
# Nix comes from the official multi-user installer, with flakes enabled. The
# configuration is evaluated with --impure: it reads USER, HOME and
# DEV_SETUP_ROOT (this checkout, which the dotfile links point into).
#
# Afterwards the zsh from Home Manager (~/.nix-profile/bin/zsh, a link that
# survives updates) becomes the login shell of $USER: Home Manager cannot change
# it outside NixOS, so the script adds it to /etc/shells and runs chsh (sudo).
#
# Any file in the way of a Home Manager link is renamed to <file>.hm-backup.
# Stow links are not removed: a machine still on Stow must run `stow -D` by hand
# before the first switch (README "Pop!_OS with Nix" gives the command).
# Otherwise the switch would keep Stow's folded directory links (e.g. ~/.gnupg)
# and write Home Manager links through them into dotfiles/, so this script
# first checks $HOME (read-only) and stops, printing that command, if it finds
# a link pointing into dotfiles/ other than through /nix/store.
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
HM_ZSH="$HOME/.nix-profile/bin/zsh"
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

# Stop before a switch that would write through Stow links: any link in $HOME
# at a path of a dotfiles/ package that points into dotfiles/ directly (Home
# Manager's links point into /nix/store). Changes nothing.
check_stow_links() {
  local dotfiles pkg rel link target dir found=""
  dotfiles=$(cd -P "$DEV_SETUP_ROOT/dotfiles" && pwd -P) || return 0
  for pkg in "$dotfiles"/*/; do
    while IFS= read -r rel; do
      link="$HOME/${rel#./}"
      [[ -L "$link" ]] || continue
      target=$(readlink "$link")
      [[ "$target" == /nix/store/* ]] && continue
      [[ "$target" == /* ]] || target="$(dirname "$link")/$target"
      dir=$(cd -P "$(dirname "$target")" 2>/dev/null && pwd -P) || continue
      [[ "$dir/$(basename "$target")" == "$dotfiles"/* ]] && found+=" $link"
    done < <(cd "$pkg" && find . -mindepth 1)
  done
  if [[ -n "$found" ]]; then
    log_error "Stow links into $dotfiles found; the Home Manager switch would write through them into the checkout:$found"
    log_stow_hint
    exit 1
  fi
}

# Make the Home Manager zsh the login shell of $USER. Does nothing if it
# already is.
set_login_shell() {
  local current
  current=$(getent passwd "$USER" | cut -d: -f7)
  if [[ "$current" == "$HM_ZSH" ]]; then
    log_info "Login shell is already $HM_ZSH"
    return 0
  fi

  if ! is_dry_run && [[ ! -x "$HM_ZSH" ]]; then
    log_error "$HM_ZSH not found; the Home Manager configuration should install zsh"
    exit 1
  fi

  log_info "Setting the login shell of $USER to $HM_ZSH (was ${current:-unknown})..."
  if ! grep -qxF "$HM_ZSH" /etc/shells 2>/dev/null; then
    if is_dry_run; then
      log_dry "would add $HM_ZSH to /etc/shells"
    elif ! echo "$HM_ZSH" | sudo tee -a /etc/shells >/dev/null; then
      log_error "Adding $HM_ZSH to /etc/shells failed"
      exit 1
    fi
  fi
  if ! run sudo chsh -s "$HM_ZSH" "$USER"; then
    log_error "Changing the login shell failed"
    exit 1
  fi
  if ! is_dry_run; then
    log_success "Login shell set to $HM_ZSH (takes effect at the next login)"
  fi
}

setup_home_manager() {
  if ! uses_home_manager; then
    log_error "$DEV_SETUP_OS is not set up with Home Manager (no os/$DEV_SETUP_OS/home.nix)"
    exit 1
  fi

  check_stow_links
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
    set_login_shell
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

  set_login_shell

  if [[ -e "$HOME/.local/bin/herdr" ]]; then
    log_warning "$HOME/.local/bin/herdr (from the old herdr installer) comes before the Nix herdr on the PATH. Remove it with: rm ~/.local/bin/herdr"
  fi
}

setup_home_manager
