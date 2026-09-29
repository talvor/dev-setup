#!/bin/bash

# Restore any mix of the GPG key, SSH key and firstmate files from a vault/
# folder, by running the matching restore_*.sh scripts of a dev-setup clone.
#
# Meant to be copied to a USB drive next to the vault:
#
#   <usb>/restore_vault.sh
#   <usb>/vault/{gpg_key.age,gpg_ownertrust,ssh_key_*.age,firstmate.tar.age}
#
# It asks which items to restore (several can be picked). The vault is looked
# for next to this script, then in the current directory. The restore scripts
# are taken from next to this script when it runs from the clone's scripts/,
# otherwise from the clone (default ~/Development/dev-setup, as install.sh).
# Kept compatible with bash 3.2 (macOS).

set -o pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--vault <dir>] [--repo <dir>] [--dry-run]

Options:
      --vault <dir>  Folder holding the vault/ directory (default: next to this
                     script, then the current directory)
      --repo <dir>   dev-setup clone with the restore scripts (default:
                     \$DEV_SETUP_DIR or ~/Development/dev-setup)
  -n, --dry-run      Show what would be restored; firstmate decrypts and lists
                     its files, the keys are not touched
  -h, --help         Show this help

Environment:
  FM_HOME=<dir>      Firstmate home to restore into (default: ~/firstmate)
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_PARENT=""
REPO_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --vault | --repo)
    if [[ -z "${2:-}" ]]; then
      echo "$1 needs a value" >&2
      exit 2
    fi
    if [[ "$1" == "--vault" ]]; then VAULT_PARENT="$2"; else REPO_DIR="$2"; fi
    shift
    ;;
  --vault=*) VAULT_PARENT="${1#--vault=}" ;;
  --repo=*) REPO_DIR="${1#--repo=}" ;;
  -n | --dry-run) DRY_RUN=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

# --- Locate the vault --------------------------------------------------------

# Accept either the folder holding vault/ or the vault/ folder itself
if [[ -n "$VAULT_PARENT" ]]; then
  if [[ "$(basename "$VAULT_PARENT")" == "vault" && ! -d "$VAULT_PARENT/vault" ]]; then
    VAULT_PARENT="$(dirname "$VAULT_PARENT")"
  fi
elif [[ -d "$SCRIPT_DIR/vault" ]]; then
  VAULT_PARENT="$SCRIPT_DIR"
else
  VAULT_PARENT="$PWD"
fi

if [[ ! -d "$VAULT_PARENT/vault" ]]; then
  echo "No vault/ folder found in $VAULT_PARENT"
  echo "Put this script next to vault/, or pass --vault <dir>."
  exit 1
fi
VAULT_PARENT="$(cd "$VAULT_PARENT" && pwd)"

# --- Locate the restore scripts ----------------------------------------------

if [[ -n "$REPO_DIR" ]]; then
  RESTORE_DIR="$REPO_DIR/scripts"
elif [[ -f "$SCRIPT_DIR/restore_gpg_key.sh" ]]; then
  RESTORE_DIR="$SCRIPT_DIR"
else
  RESTORE_DIR="${DEV_SETUP_DIR:-$HOME/Development/dev-setup}/scripts"
fi

for script in restore_gpg_key.sh restore_ssh_key.sh restore_firstmate.sh; do
  if [[ ! -f "$RESTORE_DIR/$script" ]]; then
    echo "Restore script not found: $RESTORE_DIR/$script"
    echo "Clone dev-setup first (install.sh), or pass --repo <dir>."
    exit 1
  fi
done

if ! command -v age >/dev/null 2>&1; then
  echo "age is not installed (on Pop!_OS ./setup.sh installs it)."
  exit 1
fi

# --- Pick what to restore ----------------------------------------------------

# Parallel lists (bash 3.2 has no associative arrays): only items whose files
# are in the vault are offered.
ITEMS=()
LABELS=()
if [[ -f "$VAULT_PARENT/vault/gpg_key.age" ]]; then
  ITEMS+=(gpg)
  LABELS+=("GPG key (gpg_key.age)")
fi
if ls "$VAULT_PARENT"/vault/ssh_key_*.age >/dev/null 2>&1; then
  ITEMS+=(ssh)
  LABELS+=("SSH key (ssh_key_*.age)")
fi
if [[ -f "$VAULT_PARENT/vault/firstmate.tar.age" ]]; then
  ITEMS+=(firstmate)
  LABELS+=("firstmate files (firstmate.tar.age) into ${FM_HOME:-$HOME/firstmate}")
fi

if [[ ${#ITEMS[@]} -eq 0 ]]; then
  echo "Nothing to restore in $VAULT_PARENT/vault"
  exit 1
fi

echo "Vault: $VAULT_PARENT/vault"
echo "Restore scripts: $RESTORE_DIR"
echo
echo "What should be restored?"
for i in "${!ITEMS[@]}"; do
  echo "  $((i + 1)). ${LABELS[$i]}"
done
echo "  a. All of the above"
echo

SELECTED=()
while [[ ${#SELECTED[@]} -eq 0 ]]; do
  printf "Pick one or more (e.g. 1 3, or a; empty to quit): "
  if ! read -r answer; then
    echo
    exit 1
  fi
  # Commas count as spaces
  answer="${answer//,/ }"
  if [[ -z "${answer// /}" ]]; then
    echo "Nothing selected."
    exit 0
  fi

  valid=1
  picked=" "
  for choice in $answer; do
    if [[ "$choice" == "a" || "$choice" == "A" ]]; then
      for i in "${!ITEMS[@]}"; do picked="$picked$i "; done
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le ${#ITEMS[@]} ]]; then
      picked="$picked$((choice - 1)) "
    else
      echo "Invalid choice: $choice (use 1-${#ITEMS[@]} or a)"
      valid=0
      break
    fi
  done
  [[ "$valid" == "1" ]] || continue

  # Keep the menu order and drop repeats
  for i in "${!ITEMS[@]}"; do
    case "$picked" in
    *" $i "*) SELECTED+=("${ITEMS[$i]}") ;;
    esac
  done
done

# --- Restore -----------------------------------------------------------------

# The restore scripts read ./vault, so run them from the folder holding it
cd "$VAULT_PARENT" || exit 1

FAILED=()
for item in "${SELECTED[@]}"; do
  echo
  echo "=== $item ==="
  case "$item" in
  gpg)
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "Would import the GPG key and owner trust from vault/"
      continue
    fi
    bash "$RESTORE_DIR/restore_gpg_key.sh" || FAILED+=(gpg)
    ;;
  ssh)
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "Would restore an SSH key into ~/.ssh from:"
      ls vault/ssh_key_*.age
      continue
    fi
    bash "$RESTORE_DIR/restore_ssh_key.sh" || FAILED+=(ssh)
    ;;
  firstmate)
    if [[ "$DRY_RUN" == "1" ]]; then
      bash "$RESTORE_DIR/restore_firstmate.sh" --dry-run || FAILED+=(firstmate)
    else
      bash "$RESTORE_DIR/restore_firstmate.sh" || FAILED+=(firstmate)
    fi
    ;;
  esac
done

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "Failed: ${FAILED[*]}"
  exit 1
fi
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run finished: ${SELECTED[*]}"
else
  echo "Restored: ${SELECTED[*]}"
fi
