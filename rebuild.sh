#!/bin/bash

# Rebuild Script
# Apply the Home Manager configuration again after changing it, without the
# other steps of setup.sh. Only hands over to scripts/setup_home_manager.sh,
# passing every argument on unchanged.
#
# Usage: ./rebuild.sh [--dry-run] [--os <id>]
# See ./rebuild.sh --help for the options.

exec bash "$(dirname "${BASH_SOURCE[0]}")/scripts/setup_home_manager.sh" "$@"
