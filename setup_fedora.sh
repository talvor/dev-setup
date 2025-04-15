#!/bin/bash

sudo dnf copr enable atim/lazygit -y
sudo dnf copr enable atim/lazydocker -y

./scripts/install_packages.sh ./packages/host.txt

./scripts/restore_ssh_key.sh
./scripts/restore_gpg_key.sh
./scripts/install_nerd_fonts.sh
