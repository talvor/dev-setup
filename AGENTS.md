# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Layout and conventions: `README.md` (Structure, Customization, Adding an OS). `main` is the single source for every OS (`fedora-atomic`, `popos`, `macos`, `omarchy`); the old per-OS branches are kept only until each OS is verified and must not be altered.
- Lists live in `lists/common/` plus `lists/<os>/`; an OS list only adds. Common holds only names identical on every package manager (no name translation).
- Package-manager commands live in `os/<os>/backend.sh` (interface documented in `os/popos/backend.sh`); the `scripts/install_*.sh` are shared. Never copy a script per OS.
- Every script supports `--dry-run` and `--os <id>`; use `run` from `lib/common.sh` for anything that changes the system. Keep scripts bash 3.2 compatible (macOS).
- Lint: every `*.sh` must pass `bash -n` and `shellcheck` (see README "Development"). `shellcheck` may not be installed on the machine.
- zsh is the only dotfile package split by OS: `~/.zshrc` sources `~/.zsh/<os>.zshrc` first, then `~/.zshrc.d/*`. `omarchy` and `macos` backends/zsh files are untested until run on those systems.

## Maintaining this file

Keep this file for knowledge useful to almost every future agent session in this project.
Do not repeat what the codebase already shows; point to the authoritative file or command instead.
Prefer rewriting or pruning existing entries over appending new ones.
When updating this file, preserve this bar for all agents and keep entries concise.
