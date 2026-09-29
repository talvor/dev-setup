# Pop!_OS. Sourced by ~/.zshrc.

# The Home Manager zsh (the login shell) skips the Debian /etc/zsh/zshrc: key
# bindings (Home, End, Delete, ...) and completion setup
[[ ! /proc/$$/exe -ef /usr/bin/zsh && -r /etc/zsh/zshrc ]] && source /etc/zsh/zshrc

# Nix and the Home Manager session (os/popos/home.nix): PATH, fonts, terminfo
[[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] &&
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
[[ -r ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]] &&
  source ~/.nix-profile/etc/profile.d/hm-session-vars.sh

# Use gpg-agent for ssh keys
gpg-connect-agent updatestartuptty /bye
unset SSH_AGENT_PID
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

alias code="flatpak run com.visualstudio.code"

# Go is installed from the upstream tarball
export PATH=$PATH:/usr/local/go/bin

unset DEV_SETUP_TMUX_SESSION