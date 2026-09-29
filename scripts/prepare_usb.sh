#!/bin/bash

# Copy restore_vault.sh and the files of this clone's vault/ onto a USB drive,
# so the keys and firstmate files can be restored from it (see
# restore_vault.sh):
#
#   <usb>/restore_vault.sh
#   <usb>/vault/<every file in vault/>
#
# Files already on the drive are replaced when they differ; nothing on the
# drive is deleted. Kept compatible with bash 3.2 (macOS).

set -o pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] <usb path>

Arguments:
  <usb path>     Folder on the USB drive to copy into (e.g. /media/\$USER/USB)

Options:
  -n, --dry-run  Show what would be copied, change nothing
  -h, --help     Show this help
USAGE
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USB_DIR=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  -n | --dry-run) DRY_RUN=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
  *)
    if [[ -n "$USB_DIR" ]]; then
      echo "Only one USB path can be given" >&2
      usage >&2
      exit 2
    fi
    USB_DIR="$1"
    ;;
  esac
  shift
done

if [[ -z "$USB_DIR" ]]; then
  echo "Missing the USB path" >&2
  usage >&2
  exit 2
fi

if [[ ! -d "$USB_DIR" ]]; then
  echo "USB path not found or not a folder: $USB_DIR"
  exit 1
fi
USB_DIR="$(cd "$USB_DIR" && pwd)"

if [[ "$USB_DIR" == "$REPO_DIR" ]]; then
  echo "The USB path is this clone; pick the drive's folder instead."
  exit 1
fi

if [[ "$DRY_RUN" != "1" && ! -w "$USB_DIR" ]]; then
  echo "Cannot write to $USB_DIR"
  exit 1
fi

VAULT_DIR="$REPO_DIR/vault"
if [[ ! -d "$VAULT_DIR" ]]; then
  echo "No vault found at $VAULT_DIR"
  echo "Create it first with the export_*.sh scripts."
  exit 1
fi

# The vault files (top level only, as the export scripts write them)
VAULT_FILES=()
for file in "$VAULT_DIR"/*; do
  [[ -f "$file" ]] && VAULT_FILES+=("$(basename "$file")")
done
if [[ ${#VAULT_FILES[@]} -eq 0 ]]; then
  echo "The vault is empty: $VAULT_DIR"
  exit 1
fi

echo "Copying the restore script and vault onto $USB_DIR..."

COPIED=0
SKIPPED=0

# copy_file <source> <target> <name shown>
copy_file() {
  local src="$1" target="$2" name="$3"

  if [[ -f "$target" ]] && cmp -s "$src" "$target"; then
    echo "  unchanged: $name"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ -e "$target" ]]; then
      echo "  would replace: $name"
    else
      echo "  would copy: $name"
    fi
  else
    # USB drives are often FAT/exFAT, which cannot keep file modes: when -p
    # fails, copy again without it
    if ! cp -p "$src" "$target" 2>/dev/null && ! cp "$src" "$target"; then
      echo "Could not copy $name to $target"
      exit 1
    fi
    echo "  copied: $name"
  fi
  COPIED=$((COPIED + 1))
}

if [[ "$DRY_RUN" != "1" ]] && ! mkdir -p "$USB_DIR/vault"; then
  echo "Could not create $USB_DIR/vault"
  exit 1
fi

copy_file "$REPO_DIR/scripts/restore_vault.sh" "$USB_DIR/restore_vault.sh" restore_vault.sh
for name in "${VAULT_FILES[@]}"; do
  copy_file "$VAULT_DIR/$name" "$USB_DIR/vault/$name" "vault/$name"
done

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run: $COPIED file(s) would be copied, $SKIPPED unchanged."
  exit 0
fi

# Flush the writes so the drive can be removed safely
sync

echo "USB drive prepared: $COPIED copied, $SKIPPED unchanged."
echo "On the new machine, clone dev-setup, then run:"
echo "  bash $USB_DIR/restore_vault.sh"
