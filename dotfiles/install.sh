#!/bin/sh

stow --target=$HOME alacritty
stow --target=$HOME bash
# stow --target=$HOME git
stow --target=$HOME neovim
stow --target=$HOME tmux
stow --target=$HOME zsh

if [ -f $HOME/.bashrc ]; then
	sed -zi '/source\s~\/\.bashrc\.d\/loadrc/!s/$/\nsource ~\/\.bashrc\.d\/loadrc\n/' ~/.bashrc
fi

# if [ -f $HOME/.zshrc ]; then
# 	sed -zi '/source\s~\/\.zshrc\.d\/loadrc/!s/$/\nsource ~\/\.zshrc\.d\/loadrc\n/' ~/.zshrc
# fi

mkdir -p $HOME/.local/share/zsh
if [ ! -f $HOME/.local/share/zsh/antigen.zsh ]; then
	echo "Installing antigen"
	curl -L git.io/antigen >$HOME/.local/share/zsh/antigen.zsh
fi

mkdir -p $HOME/.tmux
if [ ! -d $HOME/.tmux/plugins ]; then
	# Install tmux plugin manager
	echo "Installing tpm"
	mkdir -p $HOME/.tmux/plugins
	git clone https://github.com/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi
