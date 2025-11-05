#!/bin/bash

echo "Exporting GPG keys..."

TEMP_DIR=`mktemp -d`
echo "Created temp dir: $TEMP_DIR"

# check if tmp dir was created
if [ ! -d "$TEMP_DIR" ]; then
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
EXPORTED_KEY_FILE="$TEMP_DIR/my_gpg_key.asc"

# Create vault directory if it doesn't exist
mkdir -p vault

# Get the primary key ID (first secret key)
PRIMARY_KEY_ID=$(gpg --list-secret-keys --with-colons | grep '^sec' | head -1 | cut -d: -f5)

if [ -z "$PRIMARY_KEY_ID" ]; then
  echo "No GPG secret keys found."
  exit 1
fi

echo "Found primary key: $PRIMARY_KEY_ID"

# Export the GPG key (including all subkeys)
echo "Exporting the GPG key..."
gpg --export-secret-keys --armor "$PRIMARY_KEY_ID" > "$EXPORTED_KEY_FILE"

# Check if export was successful
if [ $? -ne 0 ]; then
  echo "GPG key export failed."
  exit 1
fi

# Export owner trust
echo "Exporting owner trust..."
gpg --export-ownertrust > "$OWNERTRUST_FILE"

# Check if owner trust export was successful
if [ $? -ne 0 ]; then
  echo "Owner trust export failed."
  exit 1
fi

# Encrypt the exported key with age using password
echo "Encrypting the exported key..."
# echo "$PASSWORD" | age -e -o "$ENCRYPTED_FILE" "$EXPORTED_KEY_FILE"
age -e -p -o "$ENCRYPTED_FILE" "$EXPORTED_KEY_FILE"

# Check if encryption was successful
if [ $? -ne 0 ]; then
  echo "Encryption failed."
  exit 1
fi

# Clear password from memory
unset PASSWORD
unset PASSWORD_CONFIRM

echo "GPG keys exported and encrypted successfully."
echo "Files created:"
echo "  - $ENCRYPTED_FILE (encrypted GPG key)"
echo "  - $OWNERTRUST_FILE (owner trust)"
echo ""
echo "You can now transfer these files to another machine and use restore_gpg_key.sh to import them." 