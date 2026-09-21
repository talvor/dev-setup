# ---- FZF -----
if [ ! -d $HOME/.fzf-git ]; then
	# Install fzf-git
	echo "Installing fzf-git"
	mkdir -p $HOME/.fzf-git
	git clone https://github.com/junegunn/fzf-git.sh $HOME/.fzf-git
fi

# Set up fzf key bindings and fuzzy completion
# (needs fzf 0.48 or newer; older packages such as apt on Pop!_OS lack --zsh)
if fzf --zsh >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi

# --- setup fzf theme ---
fg="#CBE0F0"
bg="#011628"
bg_highlight="#143652"
purple="#B388FF"
blue="#06BCE4"
cyan="#2CF9ED"

export FZF_DEFAULT_OPTS="--color=fg:${fg},bg:${bg},hl:${purple},fg+:${fg},bg+:${bg_highlight},hl+:${purple},info:${blue},prompt:${cyan},pointer:${cyan},marker:${cyan},spinner:${cyan},header:${cyan}"

# -- Use fd instead of fzf (Debian/Pop!_OS name the binary fdfind) --

_fzf_fd=""
if command -v fd >/dev/null 2>&1; then
  _fzf_fd="fd"
elif command -v fdfind >/dev/null 2>&1; then
  _fzf_fd="fdfind"
fi

if [ -n "$_fzf_fd" ]; then
  export FZF_DEFAULT_COMMAND="$_fzf_fd --hidden --strip-cwd-prefix --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND="$_fzf_fd --type=d --hidden --strip-cwd-prefix --exclude .git"

  # Use fd (https://github.com/sharkdp/fd) for listing path candidates.
  # - The first argument to the function ($1) is the base path to start traversal
  # - See the source code (completion.{bash,zsh}) for the details.
  _fzf_compgen_path() {
    $_fzf_fd --hidden --exclude .git . "$1"
  }

  # Use fd to generate the list for directory completion
  _fzf_compgen_dir() {
    $_fzf_fd --type=d --hidden --exclude .git . "$1"
  }
fi

source ~/.fzf-git/fzf-git.sh

if command -v eza >/dev/null 2>&1; then
  _fzf_dir_preview="eza --tree --color=always {} | head -200"
else
  _fzf_dir_preview="ls -A {} | head -200"
fi
if command -v bat >/dev/null 2>&1; then
  _fzf_file_preview="bat -n --color=always --line-range :500 {}"
else
  _fzf_file_preview="head -500 {}"
fi

show_file_or_dir_preview="if [ -d {} ]; then $_fzf_dir_preview; else $_fzf_file_preview; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview '$_fzf_dir_preview'"

# Advanced customization of fzf options via _fzf_comprun function
# - The first argument to the function is the name of the command.
# - You should make sure to pass the rest of the arguments to fzf.
_fzf_comprun() {
  local command=$1
  shift

  case "$command" in
    cd)           fzf --preview "$_fzf_dir_preview" "$@" ;;
    export|unset) fzf --preview "eval 'echo \${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                   "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}
