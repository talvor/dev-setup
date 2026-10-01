# dev-setup

Sets up a developer machine from one repository, and carries personal secrets and state between machines in an encrypted vault.

## Vault

**Vault**:
The encrypted set of entries that moves personal keys and state from one machine to the next.
_Avoid_: backup, keystore, secrets folder

**Entry**:
One kind of thing the vault carries (gpg, ssh or firstmate), exported and restored as a unit.
_Avoid_: item, backup file, archive

**Vault key**:
The key every entry is encrypted to; it is itself locked by the passphrase.
_Avoid_: master key (that is the GPG primary key), password

**Passphrase**:
The secret that unlocks the vault key; the only thing a person must remember to restore.
_Avoid_: password, vault password

**Source machine**:
The machine an export runs on; the only place the public half of the vault key is kept.
_Avoid_: old machine (when the role, not the age, is meant)

**USB copy**:
A copy of the vault module, the locked vault key and the entries on removable media, from which a fresh machine restores without a dev-setup clone.
_Avoid_: USB backup, vault USB

**Card keyring**:
The gpg entry: the public keys, card stubs and owner trust that point at private keys held on the YubiKey. It is not a backup of those private keys.
_Avoid_: GPG backup, GPG key export

**Restore backup**:
The private, per-restore folder that a restore moves each replaced file into first.
_Avoid_: .bak file, backup
