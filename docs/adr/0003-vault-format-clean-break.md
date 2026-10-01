# The 2026-10 vault format is a clean break

The new format (`<entry>.tar.age` per entry, plus `key.age`) has no reader for the earlier layout (`gpg_key.age`, plaintext `gpg_ownertrust`, `ssh_key_<name>.age`, `firstmate.tar.age`). Old vaults must be re-exported on their source machine with the new module before that machine is retired. Chosen over keeping or reading the old layout, to avoid carrying compatibility code.
