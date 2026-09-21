# dev-setup

Automated development setup using the native package manager of each OS and
dotfiles management with GNU Stow. One branch, several operating systems.

## Features

- ✅ Install command line tools
- ✅ Install GUI applications
- ✅ Install fonts
- ✅ Install CLI tools from URLs (for tools not available via package manager)
- ✅ Setup dotfiles using GNU Stow
- ✅ Setup SSH and GPG keys from encrypted vault (optional)
- ✅ Dry-run mode that shows what would happen without changing anything

## Supported operating systems

| OS id           | System                                   | Tools        | GUI apps       | Status |
| --------------- | ---------------------------------------- | ------------ | -------------- | ------ |
| `popos`         | Pop!_OS                                  | `apt`        | Flatpak        | verified with a dry run |
| `fedora-atomic` | Fedora Atomic (Silverblue, Kinoite, ...) | `rpm-ostree` | Flatpak        | **unverified** |
| `macos`         | macOS                                    | Homebrew     | Homebrew casks | **unverified** |
| `omarchy`       | Omarchy (Arch Linux)                     | `pacman`     | `pacman`       | **unverified, untested backend** |

`fedora-atomic`, `macos` and `omarchy` have not been run since the move to a
single branch. Treat them as unverified until they have been run on those
systems; start with `./setup.sh --dry-run`. Other distributions are not
supported.

The OS is detected automatically from `uname` and `/etc/os-release`. Unknown
systems stop with a message. To override the detection, pass `--os <id>` or set
`DEV_SETUP_OS=<id>`:

```bash
./setup.sh --os popos
DEV_SETUP_OS=popos ./setup.sh
```

## Prerequisites

- One of the supported operating systems
- `sudo` privileges (Linux)
- Internet connection
- On macOS, [Homebrew](https://brew.sh)

## Quick Start

```bash
# Clone this repository
git clone https://github.com/talvor/dev-setup.git
cd dev-setup

# See what would be done, without changing anything
./setup.sh --dry-run

# Run the complete setup
./setup.sh
```

## Dry run

`--dry-run` (or `-n`, or `DEV_SETUP_DRY_RUN=1`) works on `setup.sh` and on every
script below. It prints each command that would run and changes nothing.
Read-only checks (is this package installed?) still run, so the output tells
you what is missing. You can preview another OS on any machine with
`--os <id>`; its package manager is simply treated as "nothing installed".

```bash
./setup.sh --dry-run
./setup.sh --dry-run --os macos
./scripts/install_tools.sh --dry-run
```

## Manual Steps

You can also run individual setup steps. They all take `--dry-run` and `--os`.

```bash
# OS specific prerequisites (only some OSes have any, e.g. popos)
./scripts/run_os_steps.sh prerequisites

# Install command line tools
./scripts/install_tools.sh

# Install applications
./scripts/install_apps.sh

# Install fonts
./scripts/install_fonts.sh

# Install tools from URLs
./scripts/install_from_urls.sh

# OS specific install scripts (only some OSes have any, e.g. fedora-atomic)
./scripts/run_os_steps.sh install

# Setup dotfiles
./scripts/setup_dotfiles.sh
```

`setup.sh` runs them in this order: prerequisites, tools, apps, fonts, URLs,
OS install scripts, dotfiles.

## Structure

```
dev-setup/
├── setup.sh                  # Main setup script
├── lib/
│   ├── common.sh             # Logging, dry run, OS detection, list reading
│   └── flatpak.sh            # Flatpak helpers shared by fedora-atomic and popos
├── scripts/                  # One shared script per install type
│   ├── install_tools.sh
│   ├── install_apps.sh
│   ├── install_fonts.sh
│   ├── install_from_urls.sh
│   ├── run_os_steps.sh       # Runs the per-OS extra steps
│   ├── setup_dotfiles.sh
│   └── {export,restore}_{ssh,gpg}_key.sh
├── os/                       # Everything that only applies to one OS
│   └── <os id>/
│       ├── backend.sh        # The package-manager commands for this OS
│       ├── prerequisites.sh  # Optional step, runs before anything is installed (popos)
│       └── install_scripts/  # Optional steps, run after the lists (fedora-atomic: autotiling)
├── lists/
│   ├── common/               # Entries for every OS
│   │   └── {tools,apps,fonts,urls}.txt
│   └── <os id>/              # Entries added on top for one OS
│       └── {tools,apps,fonts,urls}.txt
├── dotfiles/                 # Your dotfiles (managed by stow)
└── README.md
```

## Customization

For each install type the installer reads `lists/common/<type>.txt` first, then
`lists/<os id>/<type>.txt`:

- `tools.txt` - Command line tools
- `apps.txt` - GUI applications
- `fonts.txt` - Nerd Fonts
- `urls.txt` - CLI tools to install from URLs

Rules for the lists:

- An OS list only adds entries. It cannot remove one that common installs.
- Put an entry in `common` only if its name is identical on every package
  manager we support. If it is named differently, or absent, on an OS, put it in
  that OS's list. There is no name translation between package managers.
- Every `<os id>` needs all four files (they may just contain comments).
- Blank lines and lines starting with `#` are ignored.

What an entry means depends on the OS:

| OS              | `tools.txt`                                   | `apps.txt`         |
| --------------- | --------------------------------------------- | ------------------ |
| `popos`         | apt package, or `name\|key_url\|apt_repo[\|package]` for a custom APT repo | Flathub app id |
| `fedora-atomic` | package layered with `rpm-ostree` (reboot needed) | Flathub app id |
| `macos`         | brew formula, `tool#user/repo` or `tool#user/repo#url` for a tap | brew cask |
| `omarchy`       | official-repo `pacman` package                | official-repo `pacman` package |

`fonts.txt` holds Nerd Font release names (`name` or `name|family`) and is
downloaded from the Nerd Fonts GitHub releases on every OS.

## Adding an OS

1. Add the id to `SUPPORTED_OSES` and to `detect_os` in `lib/common.sh`.
2. Create `os/<id>/backend.sh` implementing the functions documented in
   `os/popos/backend.sh`.
3. Create `lists/<id>/{tools,apps,fonts,urls}.txt`.
4. Optionally add `os/<id>/prerequisites.sh` and `os/<id>/install_scripts/*.sh`.
5. Add `dotfiles/zsh/.zsh/<id>.zshrc`.

## Dotfiles

Each directory in `dotfiles/` is a Stow package and is stowed on every OS. Only
the zsh package is split by OS:

- `.zshrc` and `.zshrc.d/*.zshrc` - common config, loaded on every OS
- `.zsh/<os id>.zshrc` - one file per OS. All of them are stowed everywhere and
  `.zshrc` sources the one that matches the machine when the shell starts, before
  `.zshrc.d`. The OS is detected the same way as in `setup.sh`; set
  `DEV_SETUP_OS` in your environment to force one.

An OS file can set `DEV_SETUP_TMUX_SESSION` (start a tmux session with that name
in every terminal) and `DEV_SETUP_ZSH_MINIMAL=1` (skip `.zshrc.d`, for a plain
shell, as on the Fedora Atomic host).

### Adding Your Own Dotfiles

1. Create directories in `dotfiles/` for each application
2. Place your config files inside, mirroring your home directory structure
3. Run `./scripts/setup_dotfiles.sh` to symlink them

Example:
```
dotfiles/
├── zsh/
│   └── .zshrc
├── git/
│   └── .gitconfig
└── vim/
    └── .vimrc
```

## Installing Tools from URLs

The `urls.txt` lists allow you to install CLI tools directly from URLs. This is useful for:

- Tools not available via package managers
- Tools requiring direct installation from source
- Latest versions from GitHub releases

Tools that are already on the `PATH` are skipped.

### Format

Each line in `urls.txt` should follow this format:
```
tool-name|download-url|installation-method
```

### Installation Methods

- **script**: Downloads and executes an install script
- **binary**: Downloads a binary file and installs it to `/usr/local/bin`
- **archive**: Downloads and extracts an archive (tar.gz, zip, etc.) and installs the binary

### Examples

```
# Install Oh My Zsh via script
oh-my-zsh|https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh|script

# Install kubectl binary
kubectl|https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl|binary

# Install Terraform from archive
terraform|https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip|archive
```

## Development

Every shell script must pass `bash -n` and [shellcheck](https://www.shellcheck.net)
(`.shellcheckrc` is picked up automatically). The scripts stay compatible with
bash 3.2 because macOS ships it.

```bash
files=(setup.sh lib/*.sh scripts/*.sh os/*/*.sh os/*/install_scripts/*.sh)
for f in "${files[@]}"; do bash -n "$f"; done
shellcheck "${files[@]}"
```

## SSH and GPG Keys Setup (Optional)

### Exporting SSH and GPG Keys
To securely export your SSH keys, use the `export_ssh_key.sh` or `export_gpg_key.sh` scripts located in the `scripts/` directory. This script encrypts your private key and stores it securely.

```bash
# Export SSH key
./scripts/export_ssh_key.sh
# Export GPG key
./scripts/export_gpg_key.sh
```

The encrypted key will be saved in the `vault/` directory. You can transfer this file to another machine for restoration.

### Restoring SSH and GPG Keys
To restore keys exported from another machine, use the `restore_ssh_key.sh` or `restore_gpg_key.sh` script. This script decrypts and reinstalls your private keys.

```bash
# Restore SSH key
./scripts/restore_ssh_key.sh
# Restore GPG key
./scripts/restore_gpg_key.sh
```

These scripts use paths relative to the current directory (`vault/`), so run
them from the repository root.
