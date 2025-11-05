#!/bin/bash

echo "Restoring SSH key..."

# Variables
SSH_DIR="$HOME/.ssh"

# Check if the .ssh directory exists, create it if it doesn't
if [ ! -d "$SSH_DIR" ]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
fi

# Check for available encrypted SSH key files
AVAILABLE_FILES=()
if [ -f "vault/ssh_key_id_ed25519.age" ]; then
  AVAILABLE_FILES+=("ssh_key_id_ed25519.age")
fi
if [ -f "vault/ssh_key_id_rsa.age" ]; then
  AVAILABLE_FILES+=("ssh_key_id_rsa.age")
fi

# If no encrypted files found, show what's available and exit
if [ ${#AVAILABLE_FILES[@]} -eq 0 ]; then
  echo "No encrypted SSH key files found in vault/"
  echo "Available files:"
  ls -la vault/ssh_key_*.age 2>/dev/null || echo "No ssh_key_*.age files found"
  exit 1
fi

# If only one file found, use it automatically
if [ ${#AVAILABLE_FILES[@]} -eq 1 ]; then
  ENCRYPTED_FILE="vault/${AVAILABLE_FILES[0]}"
  SSH_FILE=$(echo "${AVAILABLE_FILES[0]}" | sed 's/ssh_key_\(.*\)\.age/\1/')
  echo "Found encrypted SSH key: $SSH_FILE"
else
  # If multiple files found, let user choose
  echo "Multiple encrypted SSH key files found:"
  for i in "${!AVAILABLE_FILES[@]}"; do
    KEY_TYPE=$(echo "${AVAILABLE_FILES[$i]}" | sed 's/ssh_key_\(.*\)\.age/\1/')
    echo "  $((i+1)). $KEY_TYPE"
  done
  
  echo -n "Select key to restore (1-${#AVAILABLE_FILES[@]}): "
  read -r choice
  
  # Validate choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#AVAILABLE_FILES[@]} ]; then
    echo "Invalid choice. Please select a number between 1 and ${#AVAILABLE_FILES[@]}."
    exit 1
  fi
  
  ENCRYPTED_FILE="vault/${AVAILABLE_FILES[$((choice-1))]}"
  SSH_FILE=$(echo "${AVAILABLE_FILES[$((choice-1))]}" | sed 's/ssh_key_\(.*\)\.age/\1/')
  echo "Selected SSH key: $SSH_FILE"
fi

SSH_BACKUP="${SSH_FILE}.bak"

# Backup the existing SSH key if it exists
if [ -f "$SSH_DIR/$SSH_FILE" ]; then
  echo "Backing up existing SSH key..."
  mv "$SSH_DIR/$SSH_FILE" "$SSH_DIR/$SSH_BACKUP"
fi

# Decrypt the SSH key
echo "Decrypting the SSH key..."
age -d "$ENCRYPTED_FILE" > "$SSH_DIR/$SSH_FILE"

# Check if decryption was successful
if [ $? -ne 0 ]; then
  echo "Decryption failed."
  rm -f "$SSH_DIR/$SSH_FILE"
  if [ -f "$SSH_DIR/$SSH_BACKUP" ]; then
    mv "$SSH_DIR/$SSH_BACKUP" "$SSH_DIR/$SSH_FILE"
  fi
  exit 1
fi

# Set the appropriate permissions
chmod 600 "$SSH_DIR/$SSH_FILE"

# Create the public key file
ssh-keygen -f "$SSH_DIR/$SSH_FILE" -y > "$SSH_DIR/$SSH_FILE.pub"

echo "SSH key restored successfully."
