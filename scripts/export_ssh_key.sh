#!/bin/bash

echo "Exporting SSH key..."

TEMP_DIR=`mktemp -d`

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
SSH_DIR="$HOME/.ssh"
EXPORTED_KEY_FILE=""

# Create vault directory if it doesn't exist
mkdir -p vault

# Check for available SSH keys
AVAILABLE_KEYS=()
if [ -f "$SSH_DIR/id_ed25519" ]; then
  AVAILABLE_KEYS+=("id_ed25519")
fi
if [ -f "$SSH_DIR/id_rsa" ]; then
  AVAILABLE_KEYS+=("id_rsa")
fi

# If no keys found, show what's available and exit
if [ ${#AVAILABLE_KEYS[@]} -eq 0 ]; then
  echo "No SSH keys found at $SSH_DIR/"
  echo "Available SSH keys:"
  ls -la "$SSH_DIR/"*.key 2>/dev/null || echo "No .key files found"
  ls -la "$SSH_DIR/id_*" 2>/dev/null || echo "No id_* files found"
  exit 1
fi

# If only one key found, use it automatically
if [ ${#AVAILABLE_KEYS[@]} -eq 1 ]; then
  SSH_FILE="${AVAILABLE_KEYS[0]}"
  echo "Found SSH key: $SSH_FILE"
else
  # If multiple keys found, let user choose
  echo "Multiple SSH keys found:"
  for i in "${!AVAILABLE_KEYS[@]}"; do
    echo "  $((i+1)). ${AVAILABLE_KEYS[$i]}"
  done
  
  echo -n "Select key to export (1-${#AVAILABLE_KEYS[@]}): "
  read -r choice
  
  # Validate choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#AVAILABLE_KEYS[@]} ]; then
    echo "Invalid choice. Please select a number between 1 and ${#AVAILABLE_KEYS[@]}."
    exit 1
  fi
  
  SSH_FILE="${AVAILABLE_KEYS[$((choice-1))]}"
  echo "Selected SSH key: $SSH_FILE"
fi

# Set the encrypted file name based on the selected key
ENCRYPTED_FILE="vault/ssh_key_${SSH_FILE}.age"
EXPORTED_KEY_FILE="$TEMP_DIR/$SSH_FILE"

# Copy the SSH key to temp directory
echo "Copying SSH key to temporary location..."
cp "$SSH_DIR/$SSH_FILE" "$EXPORTED_KEY_FILE"

# Check if copy was successful
if [ $? -ne 0 ]; then
  echo "Failed to copy SSH key."
  exit 1
fi

# Encrypt the SSH key with age
echo "Encrypting the SSH key..."
age -e -p -o "$ENCRYPTED_FILE" "$EXPORTED_KEY_FILE"

# Check if encryption was successful
if [ $? -ne 0 ]; then
  echo "Encryption failed."
  exit 1
fi

echo "SSH key exported and encrypted successfully."
echo "File created: $ENCRYPTED_FILE"
echo ""
echo "You can now transfer this file to another machine and use restore_ssh_key.sh to import it."
echo ""
echo "Note: The public key will be automatically generated during import." 