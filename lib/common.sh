#!/bin/bash

# Shared helpers for the dev-setup scripts.
# Source this file, do not execute it:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#   init_script "$@"
#
# Kept compatible with bash 3.2 (the macOS system bash): no mapfile, no
# associative arrays.

DEV_SETUP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# OS ids. Each one has os/<id>/backend.sh and lists/<id>/*.txt
SUPPORTED_OSES="fedora-atomic popos macos omarchy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_dry() {
  echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

log_newline() {
  echo -e ""
}

# --- Dry run -----------------------------------------------------------------

is_dry_run() {
  [[ "${DRY_RUN:-0}" == "1" ]]
}

# Run a command, or only print it in dry-run mode.
# Read-only queries (command -v, dpkg -s, ...) do not go through here.
run() {
  if is_dry_run; then
    log_dry "would run: $*"
    return 0
  fi
  "$@"
}

# --- OS detection ------------------------------------------------------------

# Print the OS id of the running system, or return 1 if it is not supported.
# (DEV_SETUP_OS_RELEASE points at another os-release file, for testing.)
detect_os() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
    return 0
  fi

  local os_release="${DEV_SETUP_OS_RELEASE:-/etc/os-release}"
  [[ "$(uname -s)" == "Linux" && -r "$os_release" ]] || return 1

  # Read os-release in a subshell so its variables do not leak
  (
    # shellcheck disable=SC1090,SC1091
    . "$os_release"
    id="${ID:-}"

    case "$id" in
    pop)
      echo "popos"
      ;;
    fedora)
      # Atomic desktops (Silverblue, Kinoite, ...) and CoreOS boot from ostree.
      # Inside a toolbox container os-release is the plain Fedora one, so the
      # toolbox marker counts too.
      if [[ -e /run/ostree-booted || -e /run/.toolboxenv ]] ||
        echo "${VARIANT_ID:-}" | grep -E -q 'atomic|silverblue|kinoite|coreos'; then
        echo "fedora-atomic"
      else
        exit 1
      fi
      ;;
    omarchy)
      echo "omarchy"
      ;;
    arch)
      # Omarchy is the only Arch based system in scope. UNTESTED: assumes it
      # reports ID=arch.
      echo "omarchy"
      ;;
    *)
      exit 1
      ;;
    esac
  )
}

is_supported_os() {
  local os
  for os in $SUPPORTED_OSES; do
    [[ "$os" == "$1" ]] && return 0
  done
  return 1
}

# Resolve DEV_SETUP_OS: --os argument, then $DEV_SETUP_OS, then auto-detection.
resolve_os() {
  local os="${OS_ARG:-${DEV_SETUP_OS:-}}"

  if [[ -n "$os" ]]; then
    if ! is_supported_os "$os"; then
      log_error "Unsupported OS id '$os'. Supported: $SUPPORTED_OSES"
      exit 1
    fi
    DEV_SETUP_OS="$os"
    return 0
  fi

  if ! os="$(detect_os)" || [[ -z "$os" ]]; then
    log_error "Could not detect a supported OS on this system ($(uname -s), $(grep -s '^ID=' "${DEV_SETUP_OS_RELEASE:-/etc/os-release}" || echo 'no os-release'))."
    log_error "Supported: $SUPPORTED_OSES"
    log_error "Force one with --os <id> or DEV_SETUP_OS=<id>."
    exit 1
  fi
  DEV_SETUP_OS="$os"
}

# --- Arguments ---------------------------------------------------------------

print_usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] [--os <id>]

Options:
  -n, --dry-run   Print what would be done without changing the system
      --os <id>   Use this OS instead of auto-detecting it
                  (one of: $SUPPORTED_OSES)
  -h, --help      Show this help

Environment:
  DEV_SETUP_OS=<id>      Same as --os
  DEV_SETUP_DRY_RUN=1    Same as --dry-run
USAGE
}

# Sets DRY_RUN and OS_ARG from the arguments (and DEV_SETUP_DRY_RUN).
parse_args() {
  DRY_RUN=0
  case "${DEV_SETUP_DRY_RUN:-}" in
  1 | true | yes) DRY_RUN=1 ;;
  esac
  OS_ARG=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n | --dry-run)
      DRY_RUN=1
      ;;
    --os)
      if [[ -z "${2:-}" ]]; then
        log_error "--os needs a value"
        exit 2
      fi
      OS_ARG="$2"
      shift
      ;;
    --os=*)
      OS_ARG="${1#--os=}"
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      print_usage >&2
      exit 2
      ;;
    esac
    shift
  done
}

# Parse arguments, resolve the OS, load its backend and pass both settings on
# to any child script.
init_script() {
  parse_args "$@"
  resolve_os

  local backend="$DEV_SETUP_ROOT/os/$DEV_SETUP_OS/backend.sh"
  if [[ ! -f "$backend" ]]; then
    log_error "Backend not found: $backend"
    exit 1
  fi
  # shellcheck disable=SC1090
  . "$backend"

  export DEV_SETUP_OS
  export DEV_SETUP_DRY_RUN="$DRY_RUN"

  # Say so once: child scripts inherit the marker
  if is_dry_run && [[ -z "${DEV_SETUP_BANNER_SHOWN:-}" ]]; then
    log_dry "Dry run for OS '$DEV_SETUP_OS': nothing will be changed"
  fi
  export DEV_SETUP_BANNER_SHOWN=1
}

# Make sure the package manager exists (only a warning in dry-run mode, so
# another OS can be previewed with --os on a machine that lacks its tools).
require_command() {
  local cmd="$1" hint="${2:-}"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  if is_dry_run; then
    log_warning "$cmd not found; continuing because this is a dry run"
    return 0
  fi
  log_error "$cmd is not installed.${hint:+ $hint}"
  exit 1
}

# --- Lists -------------------------------------------------------------------

# The list files of a type: the common one, then the one of the current OS.
list_files() {
  echo "$DEV_SETUP_ROOT/lists/common/$1.txt"
  echo "$DEV_SETUP_ROOT/lists/$DEV_SETUP_OS/$1.txt"
}

# Fail if a list file is missing
check_lists() {
  local file ok=0
  while IFS= read -r file; do
    if [[ ! -f "$file" ]]; then
      log_error "List file not found: $file"
      ok=1
    fi
  done < <(list_files "$1")
  return "$ok"
}

# Print the entries of one list file (nothing if it does not exist).
# Blank lines and comments are skipped and whitespace is trimmed.
list_file_entries() {
  local line
  [[ -f "$1" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    if [[ -z "$line" || "$line" == \#* ]]; then
      continue
    fi
    printf '%s\n' "$line"
  done <"$1"
}

# Print the entries of a list type: common first, then the OS-specific ones.
list_entries() {
  local file
  while IFS= read -r file; do
    list_file_entries "$file"
  done < <(list_files "$1")
}
