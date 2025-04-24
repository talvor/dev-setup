#!/usr/bin/bash

# Don't continue script if any error occurs.
set -e

sudo dnf copr enable atim/lazygit -y
sudo dnf copr enable atim/lazydocker -y
sudo dnf copr enable pgdev/ghostty -y
sudo dnf copr enable tofik/nwg-shell -y

./scripts/install_packages.sh ./packages/host.txt

./scripts/restore_ssh_key.sh
./scripts/restore_gpg_key.sh
./scripts/install_nerd_fonts.sh
./scripts/install_eza.sh

nwg-shell-installer -w -s
