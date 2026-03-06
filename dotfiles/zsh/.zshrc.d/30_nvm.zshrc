if [ ! -d $HOME/.nvm ]; then
	# Install node version manager
	echo "Installing nvm"
	curl -sS https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | sh
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
