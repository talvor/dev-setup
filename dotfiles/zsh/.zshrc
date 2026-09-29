# Common zsh config.
#
# OS specific settings live in ~/.zsh/<os>.zshrc (fedora-atomic, popos, macos,
# omarchy). All of them are stowed on every machine and the one for this
# machine is sourced below. Common snippets live in ~/.zshrc.d/*.zshrc.
#
# The OS id is detected like dev-setup's setup.sh does. Set DEV_SETUP_OS in
# your environment to force one.

# history setup
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

export GPG_TTY=$(tty)

# Print the dev-setup OS id of this machine
_dev_setup_detect_os() {
  if [[ $(uname -s) == Darwin ]]; then
    print macos
    return
  fi
  [[ -r /etc/os-release ]] || return 1

  (
    source /etc/os-release
    case $ID in
      pop) print popos ;;
      fedora)
        # Atomic host, or a toolbox container running on one
        if [[ -e /run/ostree-booted || -e /run/.toolboxenv || $VARIANT_ID == *(atomic|silverblue|kinoite|coreos)* ]]; then
          print fedora-atomic
        fi
        ;;
      omarchy | arch) print omarchy ;;
      *) [[ " $ID_LIKE " == *" arch "* ]] && print omarchy ;;
    esac
  )
}

[[ -n ${DEV_SETUP_OS:-} ]] || DEV_SETUP_OS=$(_dev_setup_detect_os)
export DEV_SETUP_OS
unset -f _dev_setup_detect_os

# OS specific config. It runs first so it can set what the common snippets
# use: DEV_SETUP_TMUX_SESSION (name of the tmux session to start, none if
# unset) and DEV_SETUP_ZSH_MINIMAL (skip ~/.zshrc.d, for a plain shell).
if [[ -f ~/.zsh/${DEV_SETUP_OS}.zshrc ]]; then
  source ~/.zsh/${DEV_SETUP_OS}.zshrc
else
  echo "zsh: no OS config for '${DEV_SETUP_OS}' (~/.zsh/${DEV_SETUP_OS}.zshrc), using common config only" >&2
fi

# Load .zshrc files from ~/.zshrc.d/
if [[ -z ${DEV_SETUP_ZSH_MINIMAL:-} && -d ~/.zshrc.d ]]; then
  for rc in ~/.zshrc.d/*.zshrc(N); do
    if [ -f "$rc" ]; then
      . "$rc"
    fi
  done
fi
unset rc

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
export PATH="$HOME/.local/bin:$PATH"
