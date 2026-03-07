mkdir -p $HOME/.local/share/zsh
if [ ! -f $HOME/.local/share/zsh/antigen.zsh ]; then
	echo "Installing antigen"
	curl -L git.io/antigen >$HOME/.local/share/zsh/antigen.zsh
fi

source $HOME/.local/share/zsh/antigen.zsh

# Load Bundles 
antigen bundle git
# antigen bundle node
# antigen bundle npm
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle command-not-found
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle tmux
antigen bundle direnv

# Tell Antigen that you're done.
antigen apply


