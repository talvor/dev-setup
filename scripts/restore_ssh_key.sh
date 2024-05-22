
#!/bin/bash

# Variables
ENCRYPTED_FILE="vault/ssh_key.age"
SSH_FILE="id_ed25519"
SSH_BACKUP="id_ed25519.bak"
SSH_DIR="$HOME/.ssh"

# Check if the .ssh directory exists, create it if it doesn't
if [ ! -d "$SSH_DIR" ]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
fi

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
  rm "$SSH_DIR/$SSH_FILE"
  mv "$SSH_DIR/$SSH_BACKUP" "$SSH_DIR/$SSH_FILE"
  exit 1
fi

# Set the appropriate permissions
chmod 600 "$SSH_DIR/$SSH_FILE"

# Create the public key file
ssh-keygen -f "$SSH_DIR/$SSH_FILE" -y > "$SSH_DIR/$SSH_FILE.pub"

echo "SSH key restored successfully."
