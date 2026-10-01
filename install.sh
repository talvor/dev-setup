#!/bin/bash

# dev-setup installer: clones the repository and prints the next steps.
# Meant to be run straight from GitHub on a fresh machine:
#
#   curl -fsSL https://raw.githubusercontent.com/talvor/dev-setup/main/install.sh | bash
#   bash <(curl -fsSL https://raw.githubusercontent.com/talvor/dev-setup/main/install.sh)
#
# It clones over HTTPS (a fresh machine has no SSH keys yet) and never runs
# setup.sh itself. An existing dev-setup clone is left in place (and fast-forwarded
# when clean); anything else at the target stops the script. Nothing is deleted
# or overwritten.
#
# Usage: install.sh [--dir <path> | <path>] [--dry-run] [--os <id>]
#   --dir <path>  where to clone (default: ~/Development/dev-setup)
#   --dry-run     print what would be done without changing anything
#   --os <id>     skip auto-detection (fedora-atomic, popos, macos, omarchy)
#   Pass arguments through a pipe with: curl ... | bash -s -- --dir <path>
#
# Environment:
#   DEV_SETUP_DIR, DEV_SETUP_DRY_RUN=1, DEV_SETUP_OS=<id>  as the options above
#   DEV_SETUP_REPO  Repository to clone (default: https://github.com/talvor/dev-setup.git)
#
# The whole script is one function called on the last line, so a truncated
# download never runs a partial script. It cannot source lib/common.sh (not
# cloned yet), so the logging and OS detection below mirror it.

main() {
  set -euo pipefail

  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local YELLOW='\033[1;33m'
  local BLUE='\033[0;34m'
  local BOLD='\033[1m'
  local NC='\033[0m'
  if [[ ! -t 1 ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
  fi

  log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
  log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
  log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
  log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
  log_newline() { echo -e ""; }
  log_dry() { echo -e "${YELLOW}[DRY-RUN]${NC} $1"; }

  local supported="fedora-atomic popos macos omarchy"
  local dry_run="${DEV_SETUP_DRY_RUN:-0}"

  # Run a command, or only print it in dry-run mode.
  run() {
    if [[ "$dry_run" == "1" ]]; then
      log_dry "would run: $*"
      return 0
    fi
    "$@"
  }

  usage() {
    cat <<USAGE
Usage: install.sh [--dir <path> | <path>] [--dry-run] [--os <id>]

Clones dev-setup (default: ~/Development/dev-setup, or \$DEV_SETUP_DIR) and
prints the next steps. It does not run setup.sh.

Options:
      --dir <path>  Where to clone
  -n, --dry-run     Print what would be done without changing anything
      --os <id>     Skip auto-detection ($supported)
  -h, --help        Show this help

Through a pipe: curl -fsSL <url>/install.sh | bash -s -- --dir <path>
USAGE
  }

  # (DEV_SETUP_OS_RELEASE points at another os-release file, for testing.)
  local os_release="${DEV_SETUP_OS_RELEASE:-/etc/os-release}"

  # Same ids as detect_os in lib/common.sh; prints nothing for other systems.
  detect_os() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
      echo "macos"
      return 0
    fi
    [[ -r "$os_release" ]] || return 0
    (
      # shellcheck disable=SC1090
      . "$os_release"
      case "${ID:-}" in
      pop) echo "popos" ;;
      fedora)
        if [[ -e /run/ostree-booted || -e /run/.toolboxenv ]] ||
          echo "${VARIANT_ID:-}" | grep -E -q 'atomic|silverblue|kinoite|coreos'; then
          echo "fedora-atomic"
        fi
        ;;
      omarchy | arch) echo "omarchy" ;;
      esac
    )
  }

  # The distribution family, for install hints on systems setup.sh does not support.
  os_family() {
    [[ -r "$os_release" ]] || return 0
    (
      # shellcheck disable=SC1090
      . "$os_release"
      case " ${ID:-} ${ID_LIKE:-} " in
      *" debian "* | *" ubuntu "*) echo "apt" ;;
      *" fedora "* | *" rhel "*) echo "dnf" ;;
      *" arch "*) echo "pacman" ;;
      esac
    )
  }

  # The command that installs package $1 on this system, or nothing if unknown.
  install_hint() {
    local pkg="$1"
    case "$os" in
    macos)
      if [[ "$pkg" == "git" ]]; then
        echo "xcode-select --install"
      else
        echo "brew install $pkg"
      fi
      ;;
    popos) echo "sudo apt install $pkg" ;;
    fedora-atomic) echo "sudo rpm-ostree install $pkg   # then reboot" ;;
    omarchy) echo "sudo pacman -S $pkg" ;;
    *)
      case "$(os_family)" in
      apt) echo "sudo apt install $pkg" ;;
      dnf) echo "sudo dnf install $pkg" ;;
      pacman) echo "sudo pacman -S $pkg" ;;
      esac
      ;;
    esac
  }

  # $1 as the user would type it: ~/... under $HOME, shell-quoted if needed.
  display_path() {
    local path="$1" rest
    if [[ "$path" == "$HOME" ]]; then
      echo "~"
      return 0
    fi
    if [[ "$path" == "$HOME"/* ]]; then
      rest="${path#"$HOME"/}"
      if [[ "$(printf '%q' "$rest")" == "$rest" ]]; then
        # shellcheck disable=SC2088 # shown to the user, not expanded
        echo "~/$rest"
        return 0
      fi
    fi
    printf '%q\n' "$path"
  }

  # A git work tree rooted at $1 that has dev-setup's entry points.
  is_dev_setup_clone() {
    local dir="$1" top
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)" || return 1
    [[ "$(cd "$top" && pwd -P)" == "$(cd "$dir" && pwd -P)" ]] || return 1
    [[ -f "$dir/setup.sh" && -f "$dir/lib/common.sh" ]]
  }

  # Fast-forward an existing clone, only when that is safe; never fatal.
  update_clone() {
    local dir="$1"
    if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
      log_warning "It has local changes; not updating it."
      return 0
    fi
    if ! git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      log_warning "Its current branch has no upstream; not updating it."
      return 0
    fi
    log_info "Updating it with git pull --ff-only..."
    if GIT_TERMINAL_PROMPT=0 run git -C "$dir" pull --ff-only; then
      [[ "$dry_run" == "1" ]] || log_success "Up to date."
    else
      log_warning "git pull --ff-only failed; the clone was left as it was."
    fi
  }

  # --- Arguments ---------------------------------------------------------------

  local dir="${DEV_SETUP_DIR:-$HOME/Development/dev-setup}"
  local repo="${DEV_SETUP_REPO:-https://github.com/talvor/dev-setup.git}"
  local os="${DEV_SETUP_OS:-}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
    --dir)
      if [[ -z "${2:-}" ]]; then
        log_error "--dir needs a value"
        exit 2
      fi
      dir="$2"
      shift
      ;;
    --dir=*) dir="${1#--dir=}" ;;
    --os)
      if [[ -z "${2:-}" ]]; then
        log_error "--os needs a value"
        exit 2
      fi
      os="$2"
      shift
      ;;
    --os=*) os="${1#--os=}" ;;
    -n | --dry-run) dry_run=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      log_error "Unknown option: $1"
      usage >&2
      exit 2
      ;;
    *) dir="$1" ;;
    esac
    shift
  done

  # A quoted DEV_SETUP_DIR="~/..." reaches us unexpanded
  # shellcheck disable=SC2088 # matching a literal tilde on purpose
  case "$dir" in
  "~") dir="$HOME" ;;
  "~/"*) dir="$HOME/${dir#"~/"}" ;;
  esac
  [[ "$dir" == /* ]] || dir="$PWD/$dir"
  dir="${dir%/}"

  # setup.sh needs --os too when the OS was forced to something it would not detect
  local detected os_flag=""
  detected="$(detect_os)"
  if [[ -n "$os" ]]; then
    if [[ " $supported " != *" $os "* ]]; then
      log_error "Unsupported OS id '$os'. Supported: $supported"
      exit 2
    fi
    [[ "$os" == "$detected" ]] || os_flag=" --os $os"
  else
    os="$detected"
    [[ -n "$os" ]] || os_flag=" --os <id>"
  fi

  log_info "Installing dev-setup into $(display_path "$dir")"
  if [[ -n "$os" ]]; then
    log_info "OS: $os"
  else
    log_warning "This system is not one setup.sh detects ($supported)."
  fi
  if [[ "$dry_run" == "1" ]]; then
    log_warning "Dry run: nothing will be changed."
  fi
  log_newline

  # --- git ---------------------------------------------------------------------

  if ! command -v git >/dev/null 2>&1; then
    local hint
    hint="$(install_hint git)"
    log_error "git is not installed."
    if [[ -n "$hint" ]]; then
      log_error "Install it with:  $hint"
    else
      log_error "Install it with your package manager."
    fi
    log_error "Then run this installer again."
    exit 1
  fi

  # --- Clone -------------------------------------------------------------------

  if [[ -e "$dir" ]]; then
    if [[ -d "$dir" ]] && is_dev_setup_clone "$dir"; then
      log_success "dev-setup is already cloned at $(display_path "$dir"); not cloning again."
      update_clone "$dir"
    elif [[ -d "$dir" && -z "$(ls -A "$dir")" ]]; then
      log_info "Cloning $repo into the empty directory $(display_path "$dir")..."
      GIT_TERMINAL_PROMPT=0 run git clone "$repo" "$dir"
      [[ "$dry_run" == "1" ]] || log_success "Cloned."
    else
      log_error "$(display_path "$dir") already exists and is not a dev-setup clone."
      log_error "Nothing was changed. Move it away, or choose another location:"
      log_error "  DEV_SETUP_DIR=<path> bash <(curl -fsSL https://raw.githubusercontent.com/talvor/dev-setup/main/install.sh)"
      exit 1
    fi
  else
    log_info "Cloning $repo..."
    run mkdir -p "$(dirname "$dir")"
    GIT_TERMINAL_PROMPT=0 run git clone "$repo" "$dir"
    [[ "$dry_run" == "1" ]] || log_success "Cloned into $(display_path "$dir")."
  fi

  # --- Next steps --------------------------------------------------------------

  local shown age_hint
  shown="$(display_path "$dir")"

  log_newline
  echo -e "${BOLD}Next steps${NC}"
  log_newline
  echo "1. Go to the clone:"
  echo "     cd $shown"
  if [[ -z "$os" ]]; then
    echo
    echo "   setup.sh cannot detect this system. Pick the closest supported id"
    echo "   ($supported) and pass it with --os <id>."
  fi
  case "$os" in
  macos)
    echo
    echo "   setup.sh needs Homebrew. If 'brew' is missing, install it first:"
    # shellcheck disable=SC2016 # printed for the user to run, not expanded here
    echo '     /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    ;;
  popos)
    echo
    echo "   On Pop!_OS setup.sh installs Nix and applies the Home Manager configuration."
    ;;
  fedora-atomic | omarchy)
    echo
    echo "   $os is not yet verified since the move to one branch; read the dry run carefully."
    ;;
  esac
  echo
  echo "2. Preview what setup would do (changes nothing):"
  echo "     ./setup.sh --dry-run$os_flag"
  echo
  echo "3. Run the setup:"
  echo "     ./setup.sh$os_flag"
  echo
  echo -e "${BOLD}Optional: restore keys and files from your old machine${NC}"
  echo
  echo "The encrypted vault (GPG card keyring, SSH keys, firstmate files) is not in"
  echo "git. On the old machine, with this version of dev-setup, put it on a USB drive"
  echo "(vaults made by the old export_*.sh scripts cannot be read any more):"
  echo "     ./scripts/vault.sh export"
  echo "     ./scripts/vault.sh usb <drive folder>"
  echo
  echo "Then restore on this machine from the drive (it asks which entries, and the"
  echo "vault passphrase once; it needs age):"
  age_hint="$(install_hint age)"
  if [[ "$os" == "popos" ]]; then
    echo "   (age is installed by ./setup.sh on Pop!_OS)"
  elif [[ -n "$age_hint" ]]; then
    echo "   (install age first if missing: $age_hint)"
  fi
  echo "     bash <drive folder>/vault.sh"
  if [[ "$os" == "popos" ]]; then
    echo
    echo "Restore the firstmate entry after ./setup.sh has cloned firstmate."
  fi
  echo
  echo "Once the SSH key is restored you can switch the clone to SSH:"
  echo "     git remote set-url origin git@github.com:talvor/dev-setup.git"
}

main "$@"
