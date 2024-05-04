#!/bin/bash

sudo dnf copr enable atim/lazygit -y
./scripts/install_packages.sh ./packages/dev_container.txt

if [ ! -d $HOME/.nvm ]; then
	# Install node version manager
	echo "Installing nvm"
	curl -sS https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | sh
fi

if [ ! -d $HOME/.fzf-git ]; then
	# Install fzf-git
	echo "Installing fzf-git"
	mkdir -p $HOME/.fzf-git
	git clone https://github.com/junegunn/fzf-git.sh $HOME/.fzf-git
fi
