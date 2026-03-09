#!/bin/bash

INSTALL_URL="https://raw.githubusercontent.com/nwg-piotr/autotiling/refs/heads/master/autotiling/main.py"
BINARY_PATH="/usr/local/bin/autotiling"

if [ ! -f "$BINARY_PATH" ]; then
  sudo curl -fsSL "$INSTALL_URL" -o "$BINARY_PATH"
  sudo chown root:root "$BINARY_PATH"
  sudo chmod +x "$BINARY_PATH"
  echo "autotiling installed to $BINARY_PATH"
else
  echo "autotiling is already installed at $BINARY_PATH"
fi
