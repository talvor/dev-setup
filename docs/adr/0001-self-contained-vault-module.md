# The vault module is one self-contained file

`scripts/vault.sh` does not source `lib/common.sh` and carries its own small logging and dry-run helpers, unlike every other script in the repo. It is copied alone onto a USB drive, and a fresh machine must be able to restore from that drive without cloning dev-setup. Don't "fix" the duplication by sourcing `lib/common.sh`.

## Considered Options

- A clone-bound module that reuses `lib/common.sh`: rejected because a restore would then need a clone first.
