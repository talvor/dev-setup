#!/bin/bash

# Restore the firstmate files saved by export_firstmate.sh from
# vault/firstmate.tar.age into the firstmate home. age asks for the passphrase.
#
# Run it by hand; setup.sh does not call it. An existing file that differs is
# moved into <home>/data/.restore-backup-<timestamp>/<path> before it is
# replaced. File modes are preserved.

set -o pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--home <dir>] [--dry-run]

Options:
      --home <dir>  Firstmate home to restore into (default: \$FM_HOME or ~/firstmate)
  -n, --dry-run     Decrypt and show what would be restored, change nothing
  -h, --help        Show this help
USAGE
}

FM_HOME_DIR="${FM_HOME:-$HOME/firstmate}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  --home)
    if [[ -z "${2:-}" ]]; then
      echo "--home needs a value" >&2
      exit 2
    fi
    FM_HOME_DIR="$2"
    shift
    ;;
  --home=*) FM_HOME_DIR="${1#--home=}" ;;
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

echo "Restoring firstmate files into $FM_HOME_DIR..."

# Variables
ENCRYPTED_FILE="vault/firstmate.tar.age"

if [[ ! -f "$ENCRYPTED_FILE" ]]; then
  echo "Encrypted backup not found: $ENCRYPTED_FILE (run this from the repository root)"
  exit 1
fi

# The firstmate home is a git checkout; clone it first so the restored files
# do not block the clone.
if [[ ! -d "$FM_HOME_DIR" ]]; then
  echo "Firstmate home not found: $FM_HOME_DIR"
  echo "Clone firstmate there first, or pass --home <dir>."
  exit 1
fi

if ! command -v age >/dev/null 2>&1; then
  echo "age is not installed."
  exit 1
fi

TEMP_DIR=$(mktemp -d)

# check if tmp dir was created
if [[ ! "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
  echo "Could not create temp dir"
  exit 1
fi

# deletes the temp directory (and the decrypted files in it)
function cleanup {
  rm -rf "$TEMP_DIR"
  echo "Deleted temp working directory $TEMP_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

EXTRACT_DIR="$TEMP_DIR/firstmate"
mkdir "$EXTRACT_DIR"

# Decrypt straight into tar so no plaintext archive is written to disk
echo "Decrypting the backup (age will ask for the passphrase)..."
if ! age -d "$ENCRYPTED_FILE" | tar -xpf - -C "$EXTRACT_DIR"; then
  echo "Decryption failed."
  exit 1
fi

FILE_LIST="$TEMP_DIR/files.txt"
(cd "$EXTRACT_DIR" && find . -type f | sed 's|^\./||' | LC_ALL=C sort) >"$FILE_LIST"

# Only files the export writes are restored
while IFS= read -r rel; do
  case "$rel" in
  data/captain.md | data/projects.md | data/learnings.md | config/*) ;;
  *)
    echo "Unexpected file in backup, refusing to restore: $rel"
    exit 1
    ;;
  esac
done <"$FILE_LIST"

BACKUP_DIR="$FM_HOME_DIR/data/.restore-backup-$(date +%Y%m%d%H%M%S)"
BACKED_UP=0
RESTORED=0
SKIPPED=0
while IFS= read -r rel; do
  src="$EXTRACT_DIR/$rel"
  target="$FM_HOME_DIR/$rel"

  if [[ -e "$target" ]] && cmp -s "$src" "$target"; then
    echo "  unchanged: $rel"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup="$BACKUP_DIR/$rel"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "  would replace: $rel (keeping the old one as ${backup#"$FM_HOME_DIR"/})"
    else
      if ! mkdir -p "$(dirname "$backup")" || ! mv "$target" "$backup"; then
        echo "Could not back up $target"
        exit 1
      fi
      BACKED_UP=$((BACKED_UP + 1))
      echo "  backed up: $rel -> ${backup#"$FM_HOME_DIR"/}"
    fi
  elif [[ "$DRY_RUN" == "1" ]]; then
    echo "  would restore: $rel"
  fi

  if [[ "$DRY_RUN" != "1" ]]; then
    if ! mkdir -p "$(dirname "$target")" || ! cp -p "$src" "$target"; then
      echo "Could not restore $target"
      exit 1
    fi
    echo "  restored: $rel"
  fi
  RESTORED=$((RESTORED + 1))
done <"$FILE_LIST"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run: $RESTORED file(s) would be restored, $SKIPPED unchanged."
else
  echo "Firstmate files restored successfully: $RESTORED restored, $SKIPPED unchanged."
  if [[ "$BACKED_UP" -gt 0 ]]; then
    echo "Replaced files were moved to $BACKUP_DIR"
  fi
fi
