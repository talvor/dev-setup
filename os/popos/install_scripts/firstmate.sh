#!/bin/bash

# Set up firstmate. Runs as an extra step of the popos setup.
# See ./firstmate.sh --help for options (--dry-run, --os).
#
# Clones firstmate into ~/firstmate unless that exists, and links
# ~/firstmate/projects to ~/Development. An existing ~/firstmate/projects that
# is not that link is left alone with a warning. Restoring the firstmate
# private files is a separate, manual step: scripts/restore_firstmate.sh.

# shellcheck source=../../../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../../lib/common.sh"
init_script "$@"

REPO_URL="https://github.com/kunchenguid/firstmate"
FIRSTMATE_DIR="$HOME/firstmate"
PROJECTS_DIR="$HOME/Development"
PROJECTS_LINK="$FIRSTMATE_DIR/projects"

if [[ -e "$FIRSTMATE_DIR" || -L "$FIRSTMATE_DIR" ]]; then
  log_info "firstmate is already at $FIRSTMATE_DIR"
else
  require_command git
  if ! run git clone "$REPO_URL" "$FIRSTMATE_DIR"; then
    log_error "Could not clone $REPO_URL into $FIRSTMATE_DIR"
    exit 1
  fi
  is_dry_run || log_success "firstmate cloned into $FIRSTMATE_DIR"
fi

if [[ ! -d "$PROJECTS_DIR" ]]; then
  run mkdir -p "$PROJECTS_DIR"
fi

if [[ -L "$PROJECTS_LINK" && "$(readlink "$PROJECTS_LINK")" == "$PROJECTS_DIR" ]]; then
  log_info "$PROJECTS_LINK already links to $PROJECTS_DIR"
elif [[ -e "$PROJECTS_LINK" || -L "$PROJECTS_LINK" ]]; then
  log_warning "$PROJECTS_LINK exists and is not a link to $PROJECTS_DIR; leaving it alone"
else
  run ln -s "$PROJECTS_DIR" "$PROJECTS_LINK"
  is_dry_run || log_success "Linked $PROJECTS_LINK to $PROJECTS_DIR"
fi
