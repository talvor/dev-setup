# Pop!_OS. Sourced by ~/.zshrc.

# Nix and the Home Manager session (os/popos/home.nix): PATH, fonts, terminfo
[[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]] &&
  source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
# hm-session-vars.sh only runs once per environment, but the desktop session
# exports NIX_PATH (the missing channels dir) and shells inherit the guard, so
# clear it to always apply the Home Manager values (e.g. NIX_PATH).
unset __HM_SESS_VARS_SOURCED
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