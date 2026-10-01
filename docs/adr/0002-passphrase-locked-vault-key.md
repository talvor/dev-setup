# Entries are encrypted to a passphrase-locked vault key whose public half never leaves the source machine

Each entry is encrypted to an age key (`key.age`) that is itself encrypted with the passphrase. Exports need no prompt, a restore prompts once, and tests swap in a throwaway key. Because anyone holding the public key could add a forged entry, `key.pub` stays on the source machine and the USB copy never includes it; a restore re-derives it on the new machine.

## Considered Options

- `age -p` on every file, as before: rejected because it means one prompt per file and tests that need a terminal.

## Consequences

- Losing the passphrase loses every vault.
