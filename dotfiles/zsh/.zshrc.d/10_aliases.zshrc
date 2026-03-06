# Aliases
alias reload-zsh="source ~/.zshrc"
alias edit-zsh="nvim ~/.zshrc"
alias edit-setup="nvim ~/Development/dev-setup"

# alias ls="eza --icons=always"

alias bashly='docker run --rm -it --user $(id -u):$(id -g) --volume "$PWD:/app" dannyben/bashly'
# alias httpyac="docker run -it -v ${PWD}:/data ghcr.io/anweber/httpyac:latest"

alias k='kubectl'


alias v='NVIM_APPNAME=nvim-lazyvim nvim'
alias nvim-split='~/.tmux.d/nvim_split.sh'

alias code='cursor'
alias edit='cursor'

alias syncmaster='pushd . && cd ../master && git pull && popd || popd'
alias dive='docker run -ti --rm  -v /var/run/docker.sock:/var/run/docker.sock docker.io/wagoodman/dive'


vv() {
  # Assumes all configs exist in directories named ~/.config/nvim-*
  local config=$(fd --max-depth 1 --glob 'nvim-*' ~/.config | fzf --prompt="Neovim Configs > " --height=~50% --layout=reverse --border --exit-0)
 
  # If I exit fzf without selecting a config, don't open Neovim
  [[ -z $config ]] && echo "No config selected" && return
 
  # Open Neovim with the selected config
  NVIM_APPNAME=$(basename $config) nvim $@
}
