#!/bin/sh

stow --target=$HOME alacritty
stow --target=$HOME bash
stow --target=$HOME ghostty
stow --target=$HOME git
stow --target=$HOME neovim
stow --target=$HOME rofi
stow --target=$HOME starship
stow --target=$HOME sway
stow --target=$HOME tmux
stow --target=$HOME waybar
stow --target=$HOME wlogout
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
