# Aliases
alias reload-zsh="source ~/.zshrc"
alias edit-zsh="nvim ~/.zshrc"
alias edit-devsetup="nvim ~/Development/Personal/dev-setup/"

alias ls="eza --icons=always"


alias bashly='docker run --rm -it --user $(id -u):$(id -g) --volume "$PWD:/app" dannyben/bashly'
alias httpyac="docker run -it -v ${PWD}:/data ghcr.io/anweber/httpyac:latest"

alias k='kubectl'


kubeswitch() {
  if [[ $KUBECONFIG == *"kitt"* ]]; then
    echo "Switching KUBECONFIG to local"
    export KUBECONFIG="$HOME/.kube/config"
  else
    echo "Switching KUBECONFIG to KITT"
    export KUBECONFIG=$(atlas kitt context:create --pid=$$)
    atlas kitt context
  fi
}
