#!/bin/bash

# Tests for scripts/vault.sh, through its command-line interface only.
#
# Everything runs in one throwaway temp folder: fake home folders stand in for
# machines, with a throwaway GPG key and a throwaway (unlocked) vault key in
# place of the passphrase-locked one, so nothing asks for input and the real
# keyring, ~/.ssh and firstmate home are never touched. The YubiKey path
# (card stubs) cannot be automated; check it by hand (README "Vault").
#
# Each fake home's GNUPGHOME lives outside it: gpg treats $HOME/.gnupg as the
# default home and would talk to the user's real gpg-agent through the default
# socket, which the safety check below refuses.
#
# Usage: bash tests/vault_test.sh
# Needs age, age-keygen, gpg, gpgconf, ssh-keygen and tar. Bash 3.2 compatible.

set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
VAULT_SH="$ROOT/scripts/vault.sh"
PASSED=0
FAILED=0

for cmd in age age-keygen gpg gpgconf ssh-keygen tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: $cmd is not installed (needed by the vault tests)" >&2
    exit 1
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/vault-test.XXXXXX")" || exit 1
HOMES=()

cleanup() {
  local gnupg
  for gnupg in "${HOMES[@]}"; do
    GNUPGHOME="$gnupg" gpgconf --kill all >/dev/null 2>&1
  done
  rm -rf "$WORK"
}
trap cleanup EXIT

pass() {
  PASSED=$((PASSED + 1))
  echo "ok   - $1"
}

fail() {
  FAILED=$((FAILED + 1))
  echo "FAIL - $1"
}

# check <description> <command...>
check() {
  local desc="$1"
  shift
  if "$@"; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

# The private GNUPGHOME of a fake home (outside it, see the header)
gnupg_of() {
  echo "$WORK/gnupg-${1##*/}"
}

DEFAULT_AGENT="$(env -u GNUPGHOME gpgconf --list-dirs agent-socket 2>/dev/null)"

# A fake machine: an empty home folder with its own GNUPGHOME and gpg-agent.
# Called directly (not in $(...)) so the safety exit and HOMES take effect.
new_home() {
  local home="$1" gnupg
  gnupg="$(gnupg_of "$home")"
  mkdir -p "$home" "$gnupg"
  chmod 700 "$gnupg"
  if [[ "$(HOME="$home" GNUPGHOME="$gnupg" gpgconf --list-dirs agent-socket)" == "$DEFAULT_AGENT" ]]; then
    echo "FAIL: the test keyring $gnupg would use the real gpg-agent; aborting" >&2
    exit 1
  fi
  HOMES+=("$gnupg")
}

# Run vault.sh as the given home's user
vault() {
  local home="$1"
  shift
  env -u FM_HOME -u DEV_SETUP_DRY_RUN HOME="$home" GNUPGHOME="$(gnupg_of "$home")" bash "$VAULT_SH" "$@"
}

# Every path under a home with a checksum of each file (the keyring is
# compared through gpg_state instead: gpg touches its files on every read)
snapshot() {
  (
    cd "$1" || exit 1
    find . | LC_ALL=C sort | while IFS= read -r path; do
      if [[ -f "$path" ]]; then
        echo "$path $(cksum <"$path")"
      else
        echo "$path"
      fi
    done
  )
}

# The keyring state a restore may change: secret keys and owner trust
gpg_state() {
  GNUPGHOME="$(gnupg_of "$1")" gpg --batch --with-colons --list-secret-keys 2>/dev/null | grep '^fpr'
  GNUPGHOME="$(gnupg_of "$1")" gpg --batch --export-ownertrust 2>/dev/null | grep -v '^#' | LC_ALL=C sort
}

# The type and key fields of a public key line (the comment may differ)
pub_key() {
  awk '{ print $1, $2 }' "$1"
}

same_file() {
  cmp -s "$1" "$2"
}

no_file() {
  [[ ! -e "$1" ]]
}

# ls is the portable way to read a mode (stat differs between GNU and BSD)
mode_is() {
  # shellcheck disable=SC2012
  [[ "$(ls -ld "$2" | cut -c1-10)" == "$1" ]]
}

# The newest restore backup folder of a home (names are timestamps)
newest_backup() {
  # shellcheck disable=SC2012
  ls -dt "$1"/.local/share/dev-setup/restore-backup-* 2>/dev/null | head -n 1
}

has_line() {
  printf '%s\n' "$2" | grep -q -- "$1"
}

no_plaintext_key() {
  ! grep -rq 'PRIVATE KEY' "$1"
}

no_restore_backup() {
  ! ls -d "$1"/.local/share/dev-setup/restore-backup-* >/dev/null 2>&1
}

# --- Source machine A ----------------------------------------------------------

A="$WORK/a"
new_home "$A"
A_VAULT="$A/.local/share/dev-setup/vault"

HOME="$A" GNUPGHOME="$(gnupg_of "$A")" gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-gen-key 'Vault Test <vault-test@example.invalid>' ed25519 sign never >/dev/null 2>&1 || {
  echo "FAIL: could not create a throwaway GPG key" >&2
  exit 1
}

mkdir -p "$A/.ssh" && chmod 700 "$A/.ssh"
ssh-keygen -q -t ed25519 -N '' -C test-a -f "$A/.ssh/id_ed25519"
ssh-keygen -q -t ed25519 -N '' -C test-work -f "$A/.ssh/work_key"
echo "Host example" >"$A/.ssh/config"
echo "example ssh-ed25519 AAAA" >"$A/.ssh/known_hosts"

mkdir -p "$A/firstmate/data/task-x" "$A/firstmate/config/nested"
echo "captain" >"$A/firstmate/data/captain.md"
echo "backlog" >"$A/firstmate/data/backlog.md"
echo "report" >"$A/firstmate/data/task-x/report.md"
echo "herdr" >"$A/firstmate/config/backend"
echo "nested" >"$A/firstmate/config/nested/file"

# A throwaway vault key in place of the passphrase-locked one
mkdir -p "$A_VAULT" && chmod 700 "$A_VAULT"
age-keygen -o "$A_VAULT/key.age" 2>/dev/null
age-keygen -y "$A_VAULT/key.age" >"$A_VAULT/key.pub"

# --- Interface basics ----------------------------------------------------------

check "--help exits 0" vault "$A" --help >/dev/null
vault "$A" frobnicate >/dev/null 2>&1
check "an unknown command exits 2" [ $? -eq 2 ]

# --- Export --------------------------------------------------------------------

before="$(snapshot "$A")"
out="$(vault "$A" --dry-run export 2>&1)"
check "export --dry-run exits 0" [ $? -eq 0 ]
check "export --dry-run changes nothing" [ "$before" == "$(snapshot "$A")" ]
check "export --dry-run names what it would export" has_line "would export ssh" "$out"
vault "$A" --dry-run --vault "$WORK/fresh-vault" export >/dev/null 2>&1
check "export --dry-run does not create a new vault or key" no_file "$WORK/fresh-vault"

out="$(vault "$A" export 2>&1)"
check "export exits 0" [ $? -eq 0 ] || echo "$out"
check "export writes gpg.tar.age" [ -f "$A_VAULT/gpg.tar.age" ]
check "export writes ssh.tar.age" [ -f "$A_VAULT/ssh.tar.age" ]
check "export writes firstmate.tar.age" [ -f "$A_VAULT/firstmate.tar.age" ]
check "no private key is stored in plaintext" no_plaintext_key "$A_VAULT"

G="$WORK/g"
new_home "$G"
vault "$G" --vault "$A_VAULT" export ssh >/dev/null 2>&1
check "export of a named entry with nothing to export fails" [ $? -ne 0 ]

# --- Restore round-trip onto machine B -----------------------------------------

B="$WORK/b"
new_home "$B"
B_VAULT="$B/.local/share/dev-setup/vault"
mkdir -p "$B/firstmate"
out="$(vault "$B" --vault "$A_VAULT" restore 2>&1)"
check "restore exits 0" [ $? -eq 0 ] || echo "$out"

check "gpg: the secret key is in the new keyring" \
  [ "$(GNUPGHOME="$(gnupg_of "$A")" gpg --batch --with-colons --list-secret-keys 2>/dev/null | grep '^fpr' | head -n 1)" == \
  "$(GNUPGHOME="$(gnupg_of "$B")" gpg --batch --with-colons --list-secret-keys 2>/dev/null | grep '^fpr' | head -n 1)" ]
check "gpg: the owner trust is restored" \
  [ "$(GNUPGHOME="$(gnupg_of "$A")" gpg --batch --export-ownertrust 2>/dev/null | grep -v '^#')" == \
  "$(GNUPGHOME="$(gnupg_of "$B")" gpg --batch --export-ownertrust 2>/dev/null | grep -v '^#')" ]

check "ssh: id_ed25519 is restored" same_file "$A/.ssh/id_ed25519" "$B/.ssh/id_ed25519"
check "ssh: every private key file is restored" same_file "$A/.ssh/work_key" "$B/.ssh/work_key"
check "ssh: private keys are mode 600" mode_is -rw------- "$B/.ssh/id_ed25519"
check "ssh: ~/.ssh is mode 700" mode_is drwx------ "$B/.ssh"
check "ssh: the public key is regenerated" [ "$(pub_key "$A/.ssh/id_ed25519.pub")" == "$(pub_key "$B/.ssh/id_ed25519.pub")" ]
check "ssh: files that are not private keys stay out" no_file "$B/.ssh/config"

check "firstmate: top-level data/ files are restored" same_file "$A/firstmate/data/backlog.md" "$B/firstmate/data/backlog.md"
check "firstmate: data/captain.md is restored" same_file "$A/firstmate/data/captain.md" "$B/firstmate/data/captain.md"
check "firstmate: all of config/ is restored" same_file "$A/firstmate/config/nested/file" "$B/firstmate/config/nested/file"
check "firstmate: data/<task-id>/ folders stay out" no_file "$B/firstmate/data/task-x"

check "restore installs key.age" same_file "$A_VAULT/key.age" "$B_VAULT/key.age"
check "restore derives key.pub" same_file "$A_VAULT/key.pub" "$B_VAULT/key.pub"
check "no restore backup when nothing was replaced" no_restore_backup "$B"

# --- Dry run -------------------------------------------------------------------

C="$WORK/c"
new_home "$C"
mkdir -p "$C/firstmate"
before="$(snapshot "$C")"
gpg_before="$(gpg_state "$C")"
out="$(vault "$C" --vault "$A_VAULT" --dry-run restore 2>&1)"
check "restore --dry-run exits 0" [ $? -eq 0 ] || echo "$out"
check "restore --dry-run changes no file" [ "$before" == "$(snapshot "$C")" ]
check "restore --dry-run changes no key or trust" [ "$gpg_before" == "$(gpg_state "$C")" ]
check "restore --dry-run previews new files" has_line "new: ~/.ssh/id_ed25519" "$out"

# A fresh machine without a keyring yet: GNUPGHOME names a folder that does not exist
N="$WORK/n"
new_home "$N"
rmdir "$(gnupg_of "$N")"
before="$(snapshot "$N")"
out="$(vault "$N" --vault "$A_VAULT" --dry-run restore gpg 2>&1)"
check "restore --dry-run without a keyring exits 0" [ $? -eq 0 ] || echo "$out"
check "restore --dry-run does not create the keyring" no_file "$(gnupg_of "$N")"
check "restore --dry-run without a keyring changes no file" [ "$before" == "$(snapshot "$N")" ]
check "restore --dry-run without a keyring previews the keys as new" has_line "keys: all new" "$out"
check "restore --dry-run without a keyring previews new owner trust" has_line "new: owner trust" "$out"

echo "changed" >>"$B/firstmate/data/captain.md"
before="$(snapshot "$B")"
out="$(vault "$B" --vault "$A_VAULT" --dry-run restore firstmate 2>&1)"
check "restore --dry-run previews a replacement" has_line "would replace: ~/firstmate/data/captain.md" "$out"
check "restore --dry-run leaves a changed file alone" [ "$before" == "$(snapshot "$B")" ]

# --- The restore rule ----------------------------------------------------------

echo "changed" >>"$B/.ssh/id_ed25519"
cp "$B/.ssh/id_ed25519" "$WORK/changed-key"
cp "$B/firstmate/data/captain.md" "$WORK/changed-captain"
out="$(vault "$B" --vault "$A_VAULT" restore ssh firstmate 2>&1)"
check "restore over changed files exits 0" [ $? -eq 0 ] || echo "$out"
check "a differing file is replaced" same_file "$A/.ssh/id_ed25519" "$B/.ssh/id_ed25519"
backup="$(newest_backup "$B")"
check "the restore backup is one private folder" mode_is drwx------ "$backup"
check "the old ssh key is kept in the backup" same_file "$WORK/changed-key" "$backup/.ssh/id_ed25519"
check "the old firstmate file is kept in the backup" same_file "$WORK/changed-captain" "$backup/firstmate/data/captain.md"
check "identical files are left alone (not backed up)" no_file "$backup/firstmate/data/backlog.md"

fpr="$(GNUPGHOME="$(gnupg_of "$A")" gpg --batch --with-colons --list-secret-keys 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')"
echo "$fpr:4:" | GNUPGHOME="$(gnupg_of "$B")" gpg --batch --import-ownertrust 2>/dev/null
out="$(vault "$B" --vault "$A_VAULT" restore gpg 2>&1)"
check "restore over changed owner trust exits 0" [ $? -eq 0 ] || echo "$out"
backup="$(newest_backup "$B")"
check "the old owner trust is kept in the backup" grep -q "^$fpr:4:" "$backup/gpg-ownertrust.txt"
check "the owner trust is put back" [ "$(gpg_state "$A" | grep -v '^fpr')" == "$(gpg_state "$B" | grep -v '^fpr')" ]

# --- The menu offers exactly what restore accepts -------------------------------

M_VAULT="$WORK/m-vault"
mkdir -p "$M_VAULT"
cp "$A_VAULT/key.age" "$A_VAULT/key.pub" "$M_VAULT/"
vault "$A" --vault "$M_VAULT" export ssh firstmate >/dev/null 2>&1
D="$WORK/d"
new_home "$D"
mkdir -p "$D/firstmate"
out="$(printf '\n' | vault "$D" --vault "$M_VAULT" 2>&1)"
offered="$(printf '%s\n' "$out" | sed -n 's/^  [0-9]*\. \([a-z]*\):.*/\1/p' | tr '\n' ' ')"
check "the menu offers exactly the entries in the vault" [ "$offered" == "ssh firstmate " ]
vault "$D" --vault "$M_VAULT" restore gpg >/dev/null 2>&1
check "restore refuses an entry the vault does not hold" [ $? -ne 0 ]
printf 'a\n' | vault "$D" --vault "$M_VAULT" --dry-run >/dev/null 2>&1
check "restore accepts everything the menu offers" [ $? -eq 0 ]

# --- USB copy ------------------------------------------------------------------

USB="$WORK/usb"
mkdir -p "$USB"
vault "$A" --dry-run usb "$USB" >/dev/null 2>&1
check "usb --dry-run copies nothing" [ -z "$(ls -A "$USB")" ]
out="$(vault "$A" usb "$USB" 2>&1)"
check "usb exits 0" [ $? -eq 0 ] || echo "$out"
check "usb copies the module" same_file "$VAULT_SH" "$USB/vault.sh"
check "usb copies key.age and the entries" [ -f "$USB/key.age" -a -f "$USB/gpg.tar.age" -a -f "$USB/ssh.tar.age" -a -f "$USB/firstmate.tar.age" ]
check "key.pub never reaches the USB copy" no_file "$USB/key.pub"

# Restore on a fresh machine from the USB copy alone (no --vault, no clone)
E="$WORK/e"
new_home "$E"
mkdir -p "$E/firstmate"
out="$(env -u FM_HOME -u DEV_SETUP_DRY_RUN HOME="$E" GNUPGHOME="$(gnupg_of "$E")" bash "$USB/vault.sh" restore 2>&1)"
check "the USB copy restores on its own" [ $? -eq 0 ] || echo "$out"
check "the USB restore brings the ssh key" same_file "$A/.ssh/id_ed25519" "$E/.ssh/id_ed25519"
check "the USB restore installs key.age" same_file "$A_VAULT/key.age" "$E/.local/share/dev-setup/vault/key.age"
check "the USB restore derives key.pub the USB did not carry" same_file "$A_VAULT/key.pub" "$E/.local/share/dev-setup/vault/key.pub"

# --- A firstmate entry outside the rule is refused ------------------------------

# craft_firstmate <vault> <stage>: encrypt a hand-made firstmate entry
craft_firstmate() {
  mkdir -p "$1"
  cp "$A_VAULT/key.age" "$1/"
  (cd "$2" && find . -mindepth 1 ! -type d | sed 's|^\./||') >"$WORK/craft-list"
  tar -C "$2" -cf - -T "$WORK/craft-list" | age -R "$A_VAULT/key.pub" -o "$1/firstmate.tar.age"
}

mkdir -p "$WORK/stage-nested/data/sub"
echo "evil" >"$WORK/stage-nested/data/sub/evil.md"
echo "fine" >"$WORK/stage-nested/data/fine.md"
craft_firstmate "$WORK/r-vault" "$WORK/stage-nested"
F="$WORK/f"
new_home "$F"
mkdir -p "$F/firstmate"
vault "$F" --vault "$WORK/r-vault" restore firstmate >/dev/null 2>&1
check "a file outside the firstmate rule is refused" [ $? -ne 0 ]
check "a refused entry writes nothing" [ -z "$(ls -A "$F/firstmate")" ]

mkdir -p "$WORK/stage-link/data"
ln -s /etc/hostname "$WORK/stage-link/data/link.md"
craft_firstmate "$WORK/s-vault" "$WORK/stage-link"
vault "$F" --vault "$WORK/s-vault" restore firstmate >/dev/null 2>&1
check "an entry holding a symlink is refused" [ $? -ne 0 ]
check "a refused symlink entry writes nothing" [ -z "$(ls -A "$F/firstmate")" ]

# --- Result --------------------------------------------------------------------

echo
echo "$PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
