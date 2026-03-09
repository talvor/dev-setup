#!/bin/bash

# Run all install_scripts in the scripts folder
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

for script in "$(dirname "$0")"/../install_scripts/*.sh; do
  if [ -f "$script" ]; then
    log_info "Running $(basename "$script")..."
    bash "$script"
  fi
done
