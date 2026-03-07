# Create a temporary directory and store its name in a variable
TEMPD=$(mktemp -d)

session=$(cat /run/.containerenv | sed -n '2 p' | awk -F '"' 'NF>2{print $2}')
session_dir="$HOME/.cache/toolbox/$session"

# Exit if the temp directory wasn't created successfully
if [ ! -d "$TEMPD" ]; then
    >&2 echo "Failed to create temp directory"
    exit 1
fi

# Register a function to be called on script exit to remove the directory
function cleanup {
    rm -rf "$TEMPD"
    echo "Deleted temp working directory $TEMPD"
}

trap cleanup EXIT

tools=(
  tmux
  neovim
  direnv
  fzf
)

if [[ ! -e "$session_dir/init_complete" ]]; then
  # Change to the temporary directory
  pushd && cd "$TEMPD"

  echo "Initializing toolbox $session"

  echo "Installing tools..."
  sudo dnf install --skip-unavailable -y $tools[@]

  echo "Installing starship prompt"
  dnf copr enable -y atim/starship
  dnf install -y starship

  echo "Installing eza"
  wget -c https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -O - | tar xz
  sudo chmod +x eza
  sudo chown root:root eza
  sudo mv eza /usr/local/bin/eza

  popd
  mkdir -p "$session_dir"
  touch "$session_dir/init_complete"
fi

