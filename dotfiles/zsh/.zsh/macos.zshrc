# macOS. Sourced by ~/.zshrc.
#
# UNTESTED: this OS had no zsh config before. It only puts Homebrew on the
# PATH (Apple Silicon or Intel prefix) so tools installed by dev-setup are found.

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
