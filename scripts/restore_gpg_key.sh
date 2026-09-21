#!/bin/bash

echo "Restoring gpg key..."

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
ENCRYPTED_FILE="vault/gpg_key.age"
OWNERTRUST_FILE="vault/gpg_ownertrust"
DECRYPTED_FILE="$TEMP_DIR/my_gpg_key.asc"

# Decrypt the GPG key
echo "Decrypting the GPG key..."
# Check if decryption was successful
if ! age -d "$ENCRYPTED_FILE" > "$DECRYPTED_FILE"; then
  echo "Decryption failed."
  exit 1
fi

# Import the GPG key
echo "Importing the GPG key..."
# Check if import was successful
if ! gpg --import-options=restore,keep-ownertrust --import "$DECRYPTED_FILE"; then
  echo "GPG key import failed."
  exit 1
fi

# Update owner trust
echo "Updating owner trust..."
gpg --import-ownertrust "$OWNERTRUST_FILE"

echo "GPG key restored successfully."

