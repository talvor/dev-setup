#!/bin/bash

# Back up the private files of the firstmate home into vault/firstmate.tar.age,
# encrypted with an age passphrase (age asks for it; it is never an argument).
#
# Files: data/captain.md, data/projects.md, data/learnings.md (if present) and
# every file under config/. Restore them with restore_firstmate.sh.

set -o pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--home <dir>] [--dry-run]

Options:
      --home <dir>  Firstmate home to back up (default: \$FM_HOME or ~/firstmate)
  -n, --dry-run     List the files that would be exported, change nothing
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

echo "Exporting firstmate files from $FM_HOME_DIR..."

if [[ ! -d "$FM_HOME_DIR" ]]; then
  echo "Firstmate home not found: $FM_HOME_DIR"
  exit 1
fi

for required in data/captain.md data/projects.md; do
  if [[ ! -f "$FM_HOME_DIR/$required" ]]; then
    echo "Required file missing: $FM_HOME_DIR/$required"
    exit 1
  fi
done

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

# deletes the temp directory
function cleanup {
  rm -rf "$TEMP_DIR"
  echo "Deleted temp working directory $TEMP_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

# Variables
ENCRYPTED_FILE="vault/firstmate.tar.age"
FILE_LIST="$TEMP_DIR/files.txt"
STAGED_FILE="$TEMP_DIR/firstmate.tar.age"

# Paths relative to the firstmate home
{
  echo "data/captain.md"
  echo "data/projects.md"
  if [[ -f "$FM_HOME_DIR/data/learnings.md" ]]; then
    echo "data/learnings.md"
  fi
  if [[ -d "$FM_HOME_DIR/config" ]]; then
    (cd "$FM_HOME_DIR" && find config -type f | LC_ALL=C sort)
  fi
} >"$FILE_LIST"

echo "Files to export:"
sed 's/^/  - /' "$FILE_LIST"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run: would encrypt these files into $ENCRYPTED_FILE"
  exit 0
fi

# Create vault directory if it doesn't exist
mkdir -p vault

# Archive and encrypt in one pipe so no plaintext archive is written to disk.
# age asks for the passphrase on the terminal.
echo "Encrypting the files (age will ask for a passphrase)..."
if ! tar -C "$FM_HOME_DIR" -cf - -T "$FILE_LIST" | age -e -p -o "$STAGED_FILE"; then
  echo "Encryption failed."
  exit 1
fi

# Only replace the previous backup once the new one is complete
if ! mv "$STAGED_FILE" "$ENCRYPTED_FILE"; then
  echo "Could not write $ENCRYPTED_FILE"
  exit 1
fi

echo "Firstmate files exported and encrypted successfully."
echo "File created: $ENCRYPTED_FILE"
echo ""
echo "You can now transfer this file to another machine and use restore_firstmate.sh to restore it."
