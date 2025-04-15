# Aliases
alias reload-zsh="source ~/.zshrc"
alias edit-zsh="nvim ~/.zshrc"

alias ls="eza --icons=always"

# alias httpyac="podman run -it --name httpyac --replace -v ${PWD}:/data ghcr.io/anweber/httpyac:latest"
# alias podman="flatpak-spawn --host podman"
# alias docker="flatpak-spawn --host docker"

# alias enterdev="SHELL=/usr/bin/zsh toolbox enter dev"

function project () {
  local ABSOLUTE_PATH="$HOME/Documents/projects" 
  local PROJECT_DIR=$(find ~/Documents/projects \( -name .git -o -name node_modules -o -name elm-stuff -o -name .stack-work \) -prune -o -type d -print | awk '{ gsub("/home/phillip/Documents/projects/", ""); print $0 }' | fzf) 

  echo "Going to $PROJECT_DIR"

  cd "$ABSOLUTE_PATH/$PROJECT_DIR"
  # cd $PROJECT_DIR
}

vv() {
  # Assumes all configs exist in directories named ~/.config/nvim-*
  local config=$(fd --max-depth 1 --glob 'nvim-*' ~/.config | fzf --prompt="Neovim Configs > " --height=~50% --layout=reverse --border --exit-0)
 
  # If I exit fzf without selecting a config, don't open Neovim
  [[ -z $config ]] && echo "No config selected" && return
 
  # Open Neovim with the selected config
  NVIM_APPNAME=$(basename $config) nvim $@
}
