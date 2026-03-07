# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc

if [[ -f /run/.containerenv && -f /run/.toolboxenv ]]; then
  echo "Updating packages..."
  sudo dnf -y upgrade

  echo "Installing zsh..."
  sudo dnf -y install zsh

  # Determine zsh path
  ZSH_PATH="$(command -v zsh)"

  echo "Setting zsh as default shell for user $USER..."
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
  fi

  chsh -s "$ZSH_PATH"

  echo "Default shell set to $ZSH_PATH"

  echo "Switching to zsh..."
  exec "$ZSH_PATH"
fi
