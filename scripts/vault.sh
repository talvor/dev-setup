#!/bin/bash

# dev-setup vault: carry personal keys and state from one machine to the next.
#
#   vault.sh export [entry...]   encrypt entries into the vault (default: all)
#   vault.sh restore [entry...]  restore entries from the vault (default: all)
#   vault.sh usb <folder>        copy this script and the vault onto a drive
#   vault.sh                     interactive restore menu
#
# Every command takes --vault <dir> and --dry-run (-n); see --help.
#
# Entries (closed set; each is one section below):
#   gpg        card keyring: the public keys, card stubs and owner trust of
#              every GPG secret key. NOT a backup of private keys held on a
#              smart card (YubiKey): those never leave the card.
#   ssh        every private key file in ~/.ssh
#   firstmate  every top-level file in data/ plus everything in config/ of the
#              firstmate home ($FM_HOME, default ~/firstmate)
#
# Vault folder (default ~/.local/share/dev-setup/vault):
#   key.age          the vault key: an age identity locked by your passphrase
#   key.pub          its public half; export encrypts to it. Never copied by
#                    `usb`: whoever holds it could add forged entries.
#   <entry>.tar.age  one age-encrypted tar per entry
#
# Export never asks for the passphrase (only the very first export, which
# creates the vault key, asks for a new one). Restore asks once, then also
# installs key.age into ~/.local/share/dev-setup/vault and derives key.pub, so
# the new machine can export with the same key. A file a restore would
# replace is first moved into one private folder per restore,
# ~/.local/share/dev-setup/restore-backup-<timestamp>/ (path kept relative to
# $HOME); identical files are left alone. restore --dry-run is a full preview:
# it decrypts into a private temp folder and changes nothing.
#
# This file is self-contained on purpose (docs/adr/0001): it is copied alone
# onto a USB drive and must run on a fresh machine without a dev-setup clone,
# so it does not source lib/common.sh. Needs bash 3.2+, age, tar, and gpg /
# ssh-keygen for those entries.

set -o pipefail
umask 077

ENTRIES="gpg ssh firstmate"
HOME_VAULT="$HOME/.local/share/dev-setup/vault"
STATE_DIR="$HOME/.local/share/dev-setup"
FM_HOME_DIR="${FM_HOME:-$HOME/firstmate}"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
STAMP="$(date +%Y%m%d%H%M%S)"

DRY_RUN=0
case "${DEV_SETUP_DRY_RUN:-}" in
1 | true | yes) DRY_RUN=1 ;;
esac
VAULT_ARG=""
TMP_DIR=""
BACKUP_DIR=""
IDENTITY=""

# --- Output ------------------------------------------------------------------

if [[ -t 1 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_dry() { echo -e "${YELLOW}[DRY-RUN]${NC} $1"; }

is_dry_run() { [[ "$DRY_RUN" == "1" ]]; }

# $1 with $HOME shown as ~
tilde() {
  # shellcheck disable=SC2088 # shown to the user, not expanded
  case "$1" in
  "$HOME") echo "~" ;;
  "$HOME"/*) echo "~/${1#"$HOME"/}" ;;
  *) echo "$1" ;;
  esac
}

usage() {
  cat <<USAGE
Usage: $(basename "$0") [command] [entry...] [--vault <dir>] [--dry-run]

Commands:
  export [entry...]   Encrypt entries into the vault (default: all). The first
                      export creates the vault key and asks for a new passphrase.
  restore [entry...]  Restore entries from the vault (default: all it holds).
                      Asks for the passphrase once.
  usb <folder>        Copy this script, key.age and the entries into <folder>
                      (a USB drive). key.pub is never copied.
  (none)              Interactive menu: pick the entries to restore.

Entries: gpg (card keyring), ssh (~/.ssh private keys), firstmate (\$FM_HOME
data/ top-level files and config/).

Options:
      --vault <dir>   Vault folder (default: next to this script if it holds
                      key.age, as on a USB drive, else
                      ~/.local/share/dev-setup/vault; export and usb always
                      default to the latter)
  -n, --dry-run       Show what would happen, change nothing (restore still
                      asks for the passphrase to preview every file)
  -h, --help          Show this help

Environment:
  FM_HOME=<dir>          firstmate home (default: ~/firstmate)
  DEV_SETUP_DRY_RUN=1    Same as --dry-run
USAGE
}

# --- Helpers -----------------------------------------------------------------

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

# Private scratch folder for staged and decrypted files, removed on exit
ensure_tmp_dir() {
  [[ -n "$TMP_DIR" ]] && return 0
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dev-setup-vault.XXXXXX")" || {
    log_error "Could not create a temporary folder"
    exit 1
  }
  chmod 700 "$TMP_DIR"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "$1 is not installed.${2:+ $2}"
    return 1
  fi
}

is_entry() {
  case " $ENTRIES " in
  *" $1 "*) return 0 ;;
  esac
  return 1
}

# Physical path of an existing folder
abs_dir() {
  (cd "$1" 2>/dev/null && pwd -P)
}

# The vault folder export and usb work on
target_vault() {
  if [[ -n "$VAULT_ARG" ]]; then
    echo "$VAULT_ARG"
  else
    echo "$HOME_VAULT"
  fi
}

# The vault folder restore and the menu read: next to this script when it
# holds a vault key (a USB copy), else the home vault
source_vault() {
  if [[ -n "$VAULT_ARG" ]]; then
    echo "$VAULT_ARG"
  elif [[ -f "$SCRIPT_DIR/key.age" ]]; then
    echo "$SCRIPT_DIR"
  else
    echo "$HOME_VAULT"
  fi
}

# Entries present in a vault folder, in the fixed order. The menu offers
# exactly these and restore accepts exactly these.
available_entries() {
  local vault="$1" entry
  for entry in $ENTRIES; do
    [[ -f "$vault/$entry.tar.age" ]] && echo "$entry"
  done
}

# --- Vault key ---------------------------------------------------------------

# Succeed if the key file is passphrase-locked (an age-encrypted file) rather
# than a plain identity (a test key, or a plugin identity such as a YubiKey)
key_is_locked() {
  local first
  first="$(head -n 1 "$1" 2>/dev/null)"
  [[ "$first" == "age-encryption.org/v1" || "$first" == "-----BEGIN AGE ENCRYPTED FILE-----" ]]
}

# Load the vault key into IDENTITY, asking for the passphrase once if it is
# locked. The key only ever lives in memory.
unlock_key() {
  local key="$1"
  if key_is_locked "$key"; then
    log_info "Unlocking the vault key (age asks for your passphrase)..."
    IDENTITY="$(age -d "$key")" || {
      log_error "Could not unlock $(tilde "$key") (wrong passphrase?)"
      return 1
    }
  else
    IDENTITY="$(cat "$key")" || return 1
  fi
  if ! printf '%s\n' "$IDENTITY" | grep -qE '^AGE-(SECRET-KEY|PLUGIN)-'; then
    log_error "$(tilde "$key") does not hold an age identity"
    return 1
  fi
}

# Print the public key of IDENTITY
derive_pub() {
  printf '%s\n' "$IDENTITY" | age-keygen -y
}

# Make sure the vault folder has key.pub for export: create the vault key on
# the first export, or derive key.pub from an existing key.age.
ensure_export_key() {
  local vault="$1" tmp_key
  if [[ -s "$vault/key.pub" && ! -f "$vault/key.age" ]]; then
    log_error "$(tilde "$vault") has key.pub but no key.age: entries exported now could never be restored"
    return 1
  fi
  if [[ -s "$vault/key.pub" ]]; then
    return 0
  fi

  if [[ -f "$vault/key.age" ]]; then
    if is_dry_run; then
      log_dry "would unlock $(tilde "$vault/key.age") (asks for your passphrase) to write key.pub"
      return 0
    fi
    unlock_key "$vault/key.age" || return 1
  else
    if is_dry_run; then
      log_dry "would create a new vault key in $(tilde "$vault") (asks for a new passphrase)"
      return 0
    fi
    require_cmd age-keygen || return 1
    log_info "Creating the vault key. age asks for a new passphrase: it is the one thing you need to restore."
    IDENTITY="$(age-keygen 2>/dev/null)" || {
      log_error "age-keygen failed"
      return 1
    }
    tmp_key="$vault/key.age.tmp.$$"
    if ! printf '%s\n' "$IDENTITY" | age -p -o "$tmp_key"; then
      rm -f "$tmp_key"
      log_error "Could not lock the new vault key with a passphrase"
      return 1
    fi
    mv "$tmp_key" "$vault/key.age" || return 1
    chmod 600 "$vault/key.age"
  fi

  derive_pub >"$vault/key.pub" || {
    rm -f "$vault/key.pub"
    log_error "Could not derive key.pub"
    return 1
  }
  chmod 600 "$vault/key.pub"
}

# --- Restore rule ------------------------------------------------------------

# One private folder per restore, created on first use
ensure_backup_dir() {
  [[ -n "$BACKUP_DIR" ]] && return 0
  BACKUP_DIR="$STATE_DIR/restore-backup-$STAMP"
  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
}

# Where the old copy of a target goes: its path relative to $HOME inside the
# backup folder
backup_path() {
  local target="$1" path
  case "$target" in
  "$HOME"/*) path="$BACKUP_DIR/${target#"$HOME"/}" ;;
  *) path="$BACKUP_DIR/_root$target" ;;
  esac
  # Never overwrite an earlier backup made in the same second
  while [[ -e "$path" || -L "$path" ]]; do
    path="$path.$RANDOM"
  done
  echo "$path"
}

# Move an existing file into the restore backup
back_up() {
  local target="$1" dest
  ensure_backup_dir || return 1
  dest="$(backup_path "$target")"
  mkdir -p "$(dirname "$dest")" && mv "$target" "$dest"
}

# The one restore rule: an identical file is left alone; a file that differs
# is moved into the restore backup first; then src is installed. mode (e.g.
# 600) is applied when given, else src's mode is kept.
place_file() {
  local src="$1" target="$2" mode="${3:-}" shown
  shown="$(tilde "$target")"

  if [[ -f "$target" && ! -L "$target" ]] && cmp -s "$src" "$target"; then
    echo "  unchanged: $shown"
    return 0
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    if is_dry_run; then
      echo "  would replace: $shown (old copy kept in the restore backup)"
      return 0
    fi
    back_up "$target" || {
      log_error "Could not back up $shown"
      return 1
    }
    echo "  replaced: $shown (old copy kept in the restore backup)"
  elif is_dry_run; then
    echo "  new: $shown"
    return 0
  else
    echo "  restored: $shown"
  fi

  mkdir -p "$(dirname "$target")" || return 1
  if [[ -n "$mode" ]]; then
    cp "$src" "$target" && chmod "$mode" "$target"
  else
    cp -p "$src" "$target"
  fi
}

# --- Entry: gpg (card keyring) -------------------------------------------------

# Fingerprints of every secret key (primary keys)
gpg_secret_fprs() {
  gpg --batch --with-colons --list-secret-keys 2>/dev/null |
    awk -F: '$1 == "sec" { want = 1; next } want && $1 == "fpr" { print $10; want = 0 }'
}

# Owner trust without comment lines, for comparison
gpg_trust_lines() {
  grep -v '^#' "$1" | LC_ALL=C sort
}

gpg_describe() {
  local count
  if ! command -v gpg >/dev/null 2>&1; then
    echo "gpg is not installed"
    return 1
  fi
  count="$(gpg_secret_fprs | grep -c .)"
  if [[ "$count" -eq 0 ]]; then
    echo "no GPG secret keys"
    return 1
  fi
  echo "card keyring of $count secret key(s): public keys, card stubs, owner trust"
}

gpg_stage() {
  local stage="$1" fprs
  fprs="$(gpg_secret_fprs)"
  # shellcheck disable=SC2086 # one argument per fingerprint
  gpg --batch --armor --export-secret-keys $fprs >"$stage/secret-keys.asc" &&
    gpg --batch --export-ownertrust >"$stage/ownertrust.txt" &&
    [[ -s "$stage/secret-keys.asc" ]]
}

gpg_path_allowed() {
  [[ "$1" == "secret-keys.asc" || "$1" == "ownertrust.txt" ]]
}

gpg_restore() {
  local src="$1" fpr have new=0 present=0 current
  require_cmd gpg || return 1
  if [[ ! -f "$src/secret-keys.asc" || ! -f "$src/ownertrust.txt" ]]; then
    log_error "The gpg entry is incomplete"
    return 1
  fi

  if is_dry_run && [[ ! -d "${GNUPGHOME:-$HOME/.gnupg}" ]]; then
    echo "  keys: all new (no GPG keyring yet)"
    echo "  new: owner trust"
    return 0
  fi

  have="$(gpg_secret_fprs)"
  while IFS= read -r fpr; do
    [[ -n "$fpr" ]] || continue
    if printf '%s\n' "$have" | grep -qx "$fpr"; then
      present=$((present + 1))
    else
      new=$((new + 1))
    fi
  done < <(gpg --batch --with-colons --import-options show-only --import "$src/secret-keys.asc" 2>/dev/null |
    awk -F: '$1 == "sec" { want = 1; next } want && $1 == "fpr" { print $10; want = 0 }')

  # Owner trust: unchanged, new (the keyring has none yet), or replaced
  # (the current trust is kept in the restore backup first)
  current="$TMP_DIR/gpg-ownertrust-current.txt"
  gpg --batch --export-ownertrust >"$current" 2>/dev/null || : >"$current"
  local trust="replace"
  if [[ "$(gpg_trust_lines "$current")" == "$(gpg_trust_lines "$src/ownertrust.txt")" ]]; then
    trust="unchanged"
  elif [[ -z "$(gpg_trust_lines "$current")" ]]; then
    trust="new"
  fi

  if is_dry_run; then
    echo "  keys: $new new, $present already in the keyring (import merges, replaces nothing)"
    case "$trust" in
    unchanged) echo "  unchanged: owner trust" ;;
    new) echo "  new: owner trust" ;;
    *) echo "  would replace: owner trust (current trust kept in the restore backup)" ;;
    esac
    return 0
  fi

  if [[ "$trust" == "replace" ]]; then
    ensure_backup_dir || return 1
    cp "$current" "$BACKUP_DIR/gpg-ownertrust.txt" || return 1
  fi
  gpg --batch --import-options restore --import "$src/secret-keys.asc" || {
    log_error "GPG key import failed"
    return 1
  }
  gpg --batch --import-ownertrust "$src/ownertrust.txt" || {
    log_error "Owner trust import failed"
    return 1
  }
  echo "  keys: $new new, $present already in the keyring"
  case "$trust" in
  unchanged) echo "  unchanged: owner trust" ;;
  new) echo "  restored: owner trust" ;;
  *) echo "  replaced: owner trust (old trust kept in the restore backup)" ;;
  esac
  echo "  This is a card keyring: plug in the YubiKey (gpg --card-status) to use keys held on it."
}

# --- Entry: ssh ----------------------------------------------------------------

# Names of the private key files in ~/.ssh
ssh_key_names() {
  local file first
  for file in "$HOME"/.ssh/*; do
    [[ -f "$file" && ! -L "$file" ]] || continue
    case "$file" in
    *.pub) continue ;;
    esac
    first="$(head -n 1 "$file" 2>/dev/null)"
    case "$first" in
    "-----BEGIN "*"PRIVATE KEY-----") basename "$file" ;;
    esac
  done
}

ssh_describe() {
  local names
  names="$(ssh_key_names | tr '\n' ' ')"
  if [[ -z "$names" ]]; then
    echo "no private key files in ~/.ssh"
    return 1
  fi
  echo "private keys: ${names% }"
}

ssh_stage() {
  local stage="$1" name staged=0
  while IFS= read -r name; do
    cp -p "$HOME/.ssh/$name" "$stage/$name" || return 1
    staged=1
  done < <(ssh_key_names)
  [[ "$staged" == "1" ]]
}

ssh_path_allowed() {
  case "$1" in
  */* | .* | "") return 1 ;;
  esac
  return 0
}

ssh_restore() {
  local src="$1" name names=() pubdir="$TMP_DIR/ssh-pub" failed=0
  require_cmd ssh-keygen || return 1
  while IFS= read -r name; do
    names+=("$name")
  done < <(cd "$src" && ls)
  if [[ ! -d "$HOME/.ssh" ]]; then
    if is_dry_run; then
      echo "  new: ~/.ssh (mode 700)"
    else
      mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh" || return 1
    fi
  fi
  mkdir -p "$pubdir"

  for name in "${names[@]}"; do
    place_file "$src/$name" "$HOME/.ssh/$name" 600 || failed=1
    # Regenerate the public key from the restored private key (ssh-keygen
    # refuses a key file other users can read)
    chmod 600 "$src/$name"
    if ssh-keygen -y -P '' -f "$src/$name" >"$pubdir/$name.pub" 2>/dev/null; then
      place_file "$pubdir/$name.pub" "$HOME/.ssh/$name.pub" 644 || failed=1
    elif is_dry_run; then
      echo "  would ask for the passphrase of $name to write $name.pub"
    elif [[ -t 0 ]] && ssh-keygen -y -f "$src/$name" >"$pubdir/$name.pub"; then
      place_file "$pubdir/$name.pub" "$HOME/.ssh/$name.pub" 644 || failed=1
    else
      log_warning "Could not write ~/.ssh/$name.pub; run: ssh-keygen -y -f ~/.ssh/$name > ~/.ssh/$name.pub"
    fi
  done
  [[ "$failed" == "0" ]]
}

# --- Entry: firstmate ------------------------------------------------------------

# The firstmate rule, used for export and as the restore allowlist: a
# top-level file of data/, or anything under config/, never through "..".
firstmate_path_allowed() {
  case "/$1/" in
  *"/../"* | *"/./"* | *"//"*) return 1 ;;
  esac
  case "$1" in
  data/*/*) return 1 ;;
  data/?* | config/?*) return 0 ;;
  esac
  return 1
}

firstmate_files() {
  local rel
  [[ -d "$FM_HOME_DIR" ]] || return 0
  (cd "$FM_HOME_DIR" && find data config -type f 2>/dev/null) | LC_ALL=C sort |
    while IFS= read -r rel; do
      firstmate_path_allowed "$rel" && echo "$rel"
    done
}

firstmate_describe() {
  local count
  if [[ ! -d "$FM_HOME_DIR" ]]; then
    echo "no firstmate home at $(tilde "$FM_HOME_DIR")"
    return 1
  fi
  count="$(firstmate_files | grep -c .)"
  if [[ "$count" -eq 0 ]]; then
    echo "no files under data/ or config/ of $(tilde "$FM_HOME_DIR")"
    return 1
  fi
  echo "$count file(s) from $(tilde "$FM_HOME_DIR"): top-level data/ files and config/"
}

firstmate_stage() {
  local stage="$1" rel staged=0
  while IFS= read -r rel; do
    mkdir -p "$stage/$(dirname "$rel")" && cp -p "$FM_HOME_DIR/$rel" "$stage/$rel" || return 1
    staged=1
  done < <(firstmate_files)
  [[ "$staged" == "1" ]]
}

firstmate_restore() {
  local src="$1" rel failed=0
  if [[ ! -d "$FM_HOME_DIR" ]]; then
    log_error "Firstmate home not found: $(tilde "$FM_HOME_DIR"). Clone firstmate there first (on Pop!_OS ./setup.sh does), or set FM_HOME."
    return 1
  fi
  while IFS= read -r rel; do
    place_file "$src/$rel" "$FM_HOME_DIR/$rel" || failed=1
  done < <(cd "$src" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
  [[ "$failed" == "0" ]]
}

# --- Entry archives ------------------------------------------------------------

entry_path_allowed() {
  "${1}_path_allowed" "$2"
}

# Decrypt one entry into $TMP_DIR/<entry>/ after checking every member:
# regular files only, every name allowed by the entry's rule.
open_entry() {
  local vault="$1" entry="$2" tar name type
  tar="$TMP_DIR/$entry.tar"
  if ! printf '%s\n' "$IDENTITY" | age -d -i - -o "$tar" "$vault/$entry.tar.age"; then
    log_error "Could not decrypt $entry.tar.age (was it made with this vault key?)"
    return 1
  fi
  while IFS= read -r type; do
    if [[ "${type:0:1}" != "-" ]]; then
      log_error "Refusing the $entry entry: it holds something other than regular files"
      return 1
    fi
  done < <(tar -tvf "$tar")
  while IFS= read -r name; do
    if ! entry_path_allowed "$entry" "$name"; then
      log_error "Refusing the $entry entry: unexpected file $name"
      return 1
    fi
  done < <(tar -tf "$tar")
  mkdir -p "$TMP_DIR/$entry" && tar -xpf "$tar" -C "$TMP_DIR/$entry"
}

# --- Commands ------------------------------------------------------------------

# Validate entry names given on the command line; print the list to work on
# (all of the default set when none is given).
pick_entries() {
  local default="$1" entry
  shift
  if [[ $# -eq 0 ]]; then
    echo "$default"
    return 0
  fi
  for entry in "$@"; do
    if ! is_entry "$entry"; then
      log_error "Unknown entry: $entry (entries: $ENTRIES)"
      return 2
    fi
  done
  echo "$*"
}

cmd_export() {
  local vault entries entry what stage list explicit=0 failed=()
  vault="$(target_vault)"
  [[ $# -gt 0 ]] && explicit=1
  entries="$(pick_entries "$ENTRIES" "$@")" || exit 2
  require_cmd age "Install age first (on Pop!_OS Home Manager does)." || exit 1

  log_info "Exporting into $(tilde "$vault")..."
  if ! is_dry_run && ! { mkdir -p "$vault" && chmod 700 "$vault"; }; then
    log_error "Could not create $(tilde "$vault")"
    exit 1
  fi
  ensure_export_key "$vault" || exit 1

  for entry in $entries; do
    if ! what="$("${entry}_describe")"; then
      if [[ "$explicit" == "1" ]]; then
        log_error "$entry: nothing to export ($what)"
        failed+=("$entry")
      else
        log_info "$entry: skipped ($what)"
      fi
      continue
    fi
    if is_dry_run; then
      log_dry "would export $entry: $what"
      continue
    fi

    ensure_tmp_dir
    stage="$TMP_DIR/stage-$entry"
    list="$TMP_DIR/list-$entry"
    mkdir -p "$stage"
    if ! "${entry}_stage" "$stage"; then
      log_error "$entry: could not collect the files"
      failed+=("$entry")
      continue
    fi
    (cd "$stage" && find . -type f | sed 's|^\./||' | LC_ALL=C sort) >"$list"
    if tar -C "$stage" -cf - -T "$list" | age -R "$vault/key.pub" -o "$vault/$entry.tar.age.tmp.$$" &&
      mv "$vault/$entry.tar.age.tmp.$$" "$vault/$entry.tar.age"; then
      chmod 600 "$vault/$entry.tar.age"
      log_success "$entry: $what"
    else
      rm -f "$vault/$entry.tar.age.tmp.$$"
      log_error "$entry: encryption failed"
      failed+=("$entry")
    fi
    rm -rf "$stage"
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    log_error "Failed: ${failed[*]}"
    exit 1
  fi
  if is_dry_run; then
    log_dry "Dry run: nothing was changed."
  else
    log_info "Copy the vault onto a USB drive with: $(tilde "$SCRIPT_PATH") usb <folder>"
  fi
}

# Install the vault key into the home vault, so the new machine exports with
# the same key. A home vault made with a different key is moved into the
# restore backup first (its entries cannot be read with the new key).
install_vault_key() {
  local src="$1" home_abs src_abs pub="$TMP_DIR/key.pub" file
  src_abs="$(abs_dir "$src")"
  home_abs="$(abs_dir "$HOME_VAULT" || true)"
  if [[ -n "$home_abs" && "$home_abs" == "$src_abs" ]]; then
    return 0
  fi

  echo "vault key -> $(tilde "$HOME_VAULT")"
  if [[ -f "$HOME_VAULT/key.age" ]] && ! cmp -s "$src/key.age" "$HOME_VAULT/key.age"; then
    for file in "$HOME_VAULT"/*.tar.age; do
      [[ -f "$file" ]] || continue
      if is_dry_run; then
        echo "  would move $(tilde "$file") to the restore backup (made with another vault key)"
      else
        back_up "$file" || return 1
        echo "  moved $(tilde "$file") to the restore backup (made with another vault key)"
      fi
    done
  fi
  if ! is_dry_run; then
    mkdir -p "$HOME_VAULT" && chmod 700 "$HOME_VAULT" || return 1
  fi
  place_file "$src/key.age" "$HOME_VAULT/key.age" 600 || return 1
  derive_pub >"$pub" || return 1
  place_file "$pub" "$HOME_VAULT/key.pub" 600
}

cmd_restore() {
  local vault available entries entry failed=()
  vault="$(source_vault)"
  if [[ ! -d "$vault" ]]; then
    log_error "No vault at $(tilde "$vault"). Pass --vault <dir>, or run the copy of this script on the USB drive."
    exit 1
  fi
  available="$(available_entries "$vault" | tr '\n' ' ')"
  available="${available% }"
  if [[ -z "$available" ]]; then
    log_error "Nothing to restore in $(tilde "$vault")"
    exit 1
  fi
  entries="$(pick_entries "$available" "$@")" || exit 2
  for entry in $entries; do
    case " $available " in
    *" $entry "*) ;;
    *)
      log_error "$(tilde "$vault") has no $entry entry (it holds: $available)"
      exit 1
      ;;
    esac
  done
  require_cmd age "Install age first (on Pop!_OS ./setup.sh does)." || exit 1
  require_cmd tar || exit 1
  if [[ ! -f "$vault/key.age" ]]; then
    log_error "No vault key (key.age) in $(tilde "$vault")"
    exit 1
  fi

  ensure_tmp_dir
  log_info "Restoring from $(tilde "$vault"): $entries"
  unlock_key "$vault/key.age" || exit 1

  for entry in $entries; do
    echo "$entry:"
    if ! open_entry "$vault" "$entry" || ! "${entry}_restore" "$TMP_DIR/$entry"; then
      failed+=("$entry")
    fi
  done
  install_vault_key "$vault" || failed+=("vault-key")
  IDENTITY=""

  if [[ -n "$BACKUP_DIR" ]]; then
    log_info "Replaced files were moved to $(tilde "$BACKUP_DIR")"
  fi
  if [[ ${#failed[@]} -gt 0 ]]; then
    log_error "Failed: ${failed[*]}"
    exit 1
  fi
  if is_dry_run; then
    log_dry "Dry run: nothing was changed."
  else
    log_success "Restored: $entries"
  fi
}

cmd_menu() {
  local vault available items=() i choice answer picked valid selected=()
  vault="$(source_vault)"
  available="$(available_entries "$vault" 2>/dev/null)"
  if [[ ! -d "$vault" || -z "$available" ]]; then
    log_error "Nothing to restore in $(tilde "$vault"). Pass --vault <dir>, or run the copy of this script on the USB drive."
    exit 1
  fi
  while IFS= read -r i; do
    items+=("$i")
  done <<<"$available"

  echo "Vault: $(tilde "$vault")"
  echo
  echo "What should be restored?"
  for i in "${!items[@]}"; do
    case "${items[$i]}" in
    gpg) echo "  $((i + 1)). gpg: card keyring (public keys, card stubs, owner trust)" ;;
    ssh) echo "  $((i + 1)). ssh: private keys into ~/.ssh" ;;
    firstmate) echo "  $((i + 1)). firstmate: private files into $(tilde "$FM_HOME_DIR")" ;;
    esac
  done
  echo "  a. All of the above"
  echo

  while [[ ${#selected[@]} -eq 0 ]]; do
    printf "Pick one or more (e.g. 1 3, or a; empty to quit): "
    if ! read -r answer; then
      echo
      exit 1
    fi
    answer="${answer//,/ }"
    if [[ -z "${answer// /}" ]]; then
      echo "Nothing selected."
      exit 0
    fi
    valid=1
    picked=" "
    for choice in $answer; do
      if [[ "$choice" == "a" || "$choice" == "A" ]]; then
        for i in "${!items[@]}"; do picked="$picked$i "; done
      elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le ${#items[@]} ]]; then
        picked="$picked$((choice - 1)) "
      else
        echo "Invalid choice: $choice (use 1-${#items[@]} or a)"
        valid=0
        break
      fi
    done
    [[ "$valid" == "1" ]] || continue
    for i in "${!items[@]}"; do
      case "$picked" in
      *" $i "*) selected+=("${items[$i]}") ;;
      esac
    done
  done

  echo
  cmd_restore "${selected[@]}"
}

copy_file() {
  local src="$1" target="$2" name
  name="$(basename "$target")"
  if [[ -f "$target" ]] && cmp -s "$src" "$target"; then
    echo "  unchanged: $name"
    return 0
  fi
  if is_dry_run; then
    if [[ -e "$target" ]]; then
      echo "  would replace: $name"
    else
      echo "  would copy: $name"
    fi
    return 0
  fi
  # USB drives are often FAT/exFAT, which cannot keep file modes: when -p
  # fails, copy again without it
  if ! cp -p "$src" "$target" 2>/dev/null && ! cp "$src" "$target"; then
    log_error "Could not copy $name to $(tilde "$target")"
    return 1
  fi
  echo "  copied: $name"
}

cmd_usb() {
  local vault folder folder_abs vault_abs entry entries
  if [[ $# -ne 1 ]]; then
    log_error "usb needs exactly one folder (the USB drive)"
    usage >&2
    exit 2
  fi
  folder="$1"
  vault="$(target_vault)"

  if [[ ! -d "$folder" ]]; then
    log_error "Not a folder: $folder"
    exit 1
  fi
  folder_abs="$(abs_dir "$folder")"
  vault_abs="$(abs_dir "$vault" || true)"
  if [[ -z "$vault_abs" || ! -f "$vault/key.age" ]]; then
    log_error "No vault key in $(tilde "$vault"); run $(basename "$0") export first"
    exit 1
  fi
  if [[ "$folder_abs" == "$vault_abs" ]]; then
    log_error "The folder is the vault itself; pick the USB drive's folder"
    exit 1
  fi
  entries="$(available_entries "$vault" | tr '\n' ' ')"
  if [[ -z "$entries" ]]; then
    log_error "The vault in $(tilde "$vault") has no entries; run $(basename "$0") export first"
    exit 1
  fi
  if ! is_dry_run && [[ ! -w "$folder_abs" ]]; then
    log_error "Cannot write to $folder_abs"
    exit 1
  fi
  if ! key_is_locked "$vault/key.age"; then
    log_warning "key.age is not locked by a passphrase: anyone with this drive can read the vault"
  fi

  log_info "Copying the vault onto $folder_abs (key.pub stays here)..."
  copy_file "$SCRIPT_PATH" "$folder_abs/vault.sh" || exit 1
  copy_file "$vault/key.age" "$folder_abs/key.age" || exit 1
  for entry in $entries; do
    copy_file "$vault/$entry.tar.age" "$folder_abs/$entry.tar.age" || exit 1
  done
  if [[ -e "$folder_abs/key.pub" ]]; then
    log_warning "$folder_abs/key.pub is on the drive; delete it: whoever holds it can add forged entries"
  fi

  if is_dry_run; then
    log_dry "Dry run: nothing was copied."
    return 0
  fi
  # Flush the writes so the drive can be removed safely
  sync
  log_success "USB drive prepared. On the new machine run: bash $folder_abs/vault.sh"
}

# --- Main --------------------------------------------------------------------

main() {
  local verb="" args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    --vault)
      if [[ -z "${2:-}" ]]; then
        log_error "--vault needs a value"
        exit 2
      fi
      VAULT_ARG="$2"
      shift
      ;;
    --vault=*) VAULT_ARG="${1#--vault=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      args+=("$@")
      break
      ;;
    -*)
      log_error "Unknown option: $1"
      usage >&2
      exit 2
      ;;
    *)
      if [[ -z "$verb" ]]; then
        verb="$1"
      else
        args+=("$1")
      fi
      ;;
    esac
    shift
  done

  if [[ -n "$VAULT_ARG" && "$VAULT_ARG" != /* ]]; then
    VAULT_ARG="$PWD/$VAULT_ARG"
  fi
  if is_dry_run; then
    log_dry "Dry run: nothing will be changed"
  fi

  case "$verb" in
  export) cmd_export "${args[@]}" ;;
  restore) cmd_restore "${args[@]}" ;;
  usb) cmd_usb "${args[@]}" ;;
  "")
    if [[ ${#args[@]} -gt 0 ]]; then
      usage >&2
      exit 2
    fi
    cmd_menu
    ;;
  *)
    log_error "Unknown command: $verb"
    usage >&2
    exit 2
    ;;
  esac
}

main "$@"
