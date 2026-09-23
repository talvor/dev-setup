# Pop!_OS. Sourced by ~/.zshrc.

# Use gpg-agent for ssh keys
gpg-connect-agent updatestartuptty /bye
unset SSH_AGENT_PID
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

alias code="flatpak run com.visualstudio.code"

# Go is installed from the upstream tarball
export PATH=$PATH:/usr/local/go/bin

unset DEV_SETUP_TMUX_SESSION