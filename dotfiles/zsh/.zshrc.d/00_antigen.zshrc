source $HOME/.local/share/zsh/antigen.zsh

# Load Bundles 
antigen bundle git
antigen bundle node
antigen bundle npm
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle command-not-found
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle tmux

# Tell Antigen that you're done.
antigen apply


eval "$(starship init zsh)"
