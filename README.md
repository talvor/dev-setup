# dev-setup

Automated development setup. One branch, several operating systems.

- **Pop!_OS** is set up with [Nix](https://nixos.org) and
  [Home Manager](https://github.com/nix-community/home-manager): CLI tools, fonts,
  Flatpak apps and dotfile links are declared in Nix (see
  [Pop!_OS with Nix](#popos-with-nix)).
- The **other systems** use their native package manager, the lists in `lists/`
  and GNU Stow for the dotfiles, until they are migrated too.

## Quick start

On a fresh machine, clone the repository and see the next steps with:

```bash
curl -fsSL https://raw.githubusercontent.com/talvor/dev-setup/main/install.sh | bash
# or
bash <(curl -fsSL https://raw.githubusercontent.com/talvor/dev-setup/main/install.sh)
```

`install.sh` clones over HTTPS into `~/Development/dev-setup` and prints the
next steps for the detected OS: preview with `./setup.sh --dry-run`, run
`./setup.sh`, then the optional restore of the SSH/GPG keys (and, on Pop!_OS,
the firstmate files) from the `vault/` folder copied from the old machine. It
never runs `setup.sh` itself. If git is missing it says how to install it.

Choose another location with `DEV_SETUP_DIR=<path>` or an argument
(`curl ... | bash -s -- --dir <path>`). An existing dev-setup clone there is
kept and only fast-forwarded when it has no local changes; anything else at the
target stops the script. Nothing is deleted or overwritten. Like the other
scripts it takes `--dry-run` and `--os <id>` (see `install.sh --help`).

Or clone by hand:

```bash
git clone https://github.com/talvor/dev-setup.git
cd dev-setup

# See what would be done, without changing anything
./setup.sh --dry-run

# Run the complete setup
./setup.sh
```

## Features

- ✅ Install command line tools
- ✅ Install GUI applications
- ✅ Install fonts
- ✅ Install CLI tools from URLs (for tools not available via package manager)
- ✅ Setup dotfiles using GNU Stow, or Home Manager links on Pop!_OS
- ✅ Setup SSH and GPG keys from encrypted vault (optional)
- ✅ Back up and restore the firstmate home's private files in an encrypted vault (optional)
- ✅ Dry-run mode that shows what would happen without changing anything

## Supported operating systems

| OS id           | System                                   | Tools        | GUI apps       | Status |
| --------------- | ---------------------------------------- | ------------ | -------------- | ------ |
| `popos`         | Pop!_OS                                  | Nix + Home Manager (root-level bits: `apt`) | Flatpak, declared with nix-flatpak | Nix config built and activated in a container; not yet applied on a real machine |
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
- On Pop!_OS nothing else: `setup.sh` installs Nix if it is missing

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
On Pop!_OS `setup.sh` runs only the prerequisites, `setup_home_manager.sh` and
the OS install scripts (see [Pop!_OS with Nix](#popos-with-nix)); the other
steps below still work there on their own, reading `lists/popos/`.

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

# Install Nix and apply the Home Manager configuration (popos only)
./scripts/setup_home_manager.sh
```

`setup.sh` runs them in this order: prerequisites, tools, apps, fonts, URLs,
OS install scripts, dotfiles.

## Pop!_OS with Nix

On Pop!_OS, `./setup.sh` runs three steps:

1. **Prerequisites** (`os/popos/prerequisites.sh`, `sudo apt`): only what needs
   root or cannot come from Nix: `curl`, `git`, `xz-utils` (Nix installer and
   flakes), `flatpak` (host integration for the apps), `fontconfig`, `zsh`
   (login shell, must be in `/etc/shells`), `alacritty` and `claude-desktop`
   (GUI apps that are not on Flathub; Nix GUI apps lack the host graphics
   drivers), `stow` (to remove the old Stow links) and `build-essential` (the
   host C toolchain).
2. **Nix and Home Manager** (`scripts/setup_home_manager.sh`): installs Nix if
   it is missing, removes the Stow links into `dotfiles/`, and applies
   `homeConfigurations.popos` from `flake.nix`.
3. **OS install scripts** (`os/popos/install_scripts/`): what Nix does not
   set up. `firstmate.sh` clones
   [firstmate](https://github.com/kunchenguid/firstmate) into `~/firstmate`
   unless that exists, creates `~/Development` and links
   `~/firstmate/projects` to it. An existing `~/firstmate/projects` that is
   anything else (a directory, or a link elsewhere) is left alone with a
   warning. Restoring firstmate's private files is not part of setup (see
   [Firstmate Backup](#firstmate-backup-optional)).

The flake follows `nixos-unstable` (with Home Manager `master`), so newer tools
such as `herdr` come straight from nixpkgs; `flake.lock` pins the exact
revision. Run `nix flake update` to move to a newer unstable revision.
Existing installs should delete the `herdr` left in `~/.local/bin` by its old
installer (`rm ~/.local/bin/herdr`): `~/.local/bin` comes first on the `PATH`,
so it shadows the Nix `herdr`. `scripts/setup_home_manager.sh` warns while it
is there, but does not delete it.

Nix is installed with the official multi-user installer
(`https://nixos.org/nix/install --daemon`): it is upstream Nix, sets up
`/etc/zsh/zshrc` and `/etc/profile.d` so Nix is on the `PATH`, and takes
`--nix-extra-conf-file`, which the script uses to enable flakes
(`experimental-features = nix-command flakes` in `/etc/nix/nix.conf`). The
scripts also enable flakes for their own calls, so an existing Nix without
them works too.

What goes where:

| What | Declared in |
| ---- | ----------- |
| CLI tools, fonts shared by every Nix OS | `nix/common.nix` (mirrors `lists/common/`) |
| Pop!_OS tools, Flatpak apps, dotfile packages | `os/popos/home.nix` |
| apt packages (root) | `os/popos/prerequisites.sh` |
| Tools not in nixpkgs, firstmate checkout | `os/popos/install_scripts/*.sh` |

- **Flatpak apps** are declared with
  [nix-flatpak](https://github.com/gmodena/nix-flatpak) (`services.flatpak`),
  from the same `flathub` remote. They are installed per user (`flatpak
  --user`) by a systemd user service that starts on switch and at login. Apps
  that are not declared are left alone, including ones installed system-wide
  by the old path.
- **Dotfiles**: `devSetup.dotfiles` lists the packages under `dotfiles/`, as
  `lists/popos/dotfiles.txt` did. Each package's top-level entries are linked
  into `$HOME` (entries of `.config`, `.gnupg` and `.local` one level down, as
  Stow does when those exist; `~/.gnupg` is created private, 700, as gpg
  requires) and the links point into this checkout, so the files stay
  editable in place. The whole `~/.zsh` directory is linked, so `~/.zshrc` still
  sources `~/.zsh/popos.zshrc`, which in turn loads the Nix and Home Manager
  session. Nix only sees files tracked by git: `git add` a new package before
  applying.
- Files already in the way of a link (such as the stock `~/.bashrc`) are
  renamed to `<file>.hm-backup`.
- **Fonts** come from nixpkgs (`nerd-fonts.*`) with fontconfig enabled. Host
  apps (the terminals) see them; Flatpak apps do not, as the sandbox has no
  `/nix/store`.

After changing a `.nix` file, apply it again with
`./scripts/setup_home_manager.sh` (quick when Nix is installed). It exports
`DEV_SETUP_ROOT` and passes `--impure`: the configuration reads `USER`, `HOME`
and `DEV_SETUP_ROOT` from the environment, so it is not tied to one user or
checkout path. By hand that is:

```bash
DEV_SETUP_ROOT=$PWD nix run .#home-manager -- switch --impure --flake .#popos -b hm-backup
```

In a dry run nothing is installed. If Nix is already installed, the dry run
also previews the switch with `home-manager switch --dry-run`, which builds
into `/nix/store` and lists every link it would make, file it would back up and
package it would install. It changes none of your files; only Nix and Home
Manager bookkeeping (`~/.cache/nix`, `~/.local/share/home-manager`) may appear.

If the switch fails after the Stow links were removed,
`./scripts/setup_dotfiles.sh` puts them back.

The files under `lists/popos/` are no longer read by `setup.sh`; they stay for
the individual scripts until the Nix path has been used on a real machine.

## Structure

```
dev-setup/
├── install.sh                # Bootstrap: clone from GitHub, print next steps
├── setup.sh                  # Main setup script
├── flake.nix, flake.lock     # Home Manager configurations (Nix OSes: popos)
├── nix/
│   ├── mk-home.nix           # Builds one OS's configuration
│   ├── common.nix            # Shared by every Nix OS (tools, fonts)
│   └── modules/              # dotfiles.nix (dotfile links), flatpak.nix (dry-run fix)
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
│   ├── setup_home_manager.sh # Installs Nix, applies the Home Manager config
│   ├── {export,restore}_{ssh,gpg}_key.sh
│   └── {export,restore}_firstmate.sh # Encrypted backup of the firstmate home's private files
├── os/                       # Everything that only applies to one OS
│   └── <os id>/
│       ├── backend.sh        # The package-manager commands for this OS
│       ├── home.nix          # Home Manager config; makes setup.sh use Nix (popos)
│       ├── prerequisites.sh  # Optional step, runs before anything is installed (popos)
│       └── install_scripts/  # Optional steps, run after the lists (fedora-atomic: autotiling, popos: firstmate)
├── lists/
│   ├── common/               # Entries for every OS
│   │   └── {tools,apps,fonts,urls}.txt
│   └── <os id>/              # Entries added on top for one OS
│       ├── {tools,apps,fonts,urls}.txt
│       └── dotfiles.txt      # Stow packages for this OS (no common file)
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
- Every `<os id>` needs all four files (they may just contain comments), plus
  `dotfiles.txt` (see [Dotfiles](#dotfiles)).
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
3. Create `lists/<id>/{tools,apps,fonts,urls,dotfiles}.txt`.
4. Optionally add `os/<id>/prerequisites.sh` and `os/<id>/install_scripts/*.sh`.
5. Add `dotfiles/zsh/.zsh/<id>.zshrc`.

### Moving an OS to Nix

Follow Pop!_OS:

1. Add `os/<id>/home.nix` with what only that OS gets (tools, apps, the
   `devSetup.dotfiles` packages). Its presence makes `setup.sh` take the Nix
   path for the OS.
2. Add the id and the systems to check to `oses` in `flake.nix`.
3. Keep root-level work in `os/<id>/prerequisites.sh`, and tools that nixpkgs
   lacks in `os/<id>/install_scripts/`.
4. Shared settings belong in `nix/common.nix`; keep it in step with
   `lists/common/`. On macOS that likely means nix-darwin or Homebrew for GUI
   apps instead of Flatpak.

## Dotfiles

Each directory in `dotfiles/` is a Stow package. `lists/<os id>/dotfiles.txt`
names the packages to stow on that OS, one per line (blank lines and `#`
comments are ignored). Unlike the other lists there is no common file: each OS
lists every package it wants, so a package can be left out on one OS (macOS
skips `sway`, `waybar` and `rofi`).

On Pop!_OS Home Manager links the packages instead of Stow; they are listed in
`devSetup.dotfiles` in `os/popos/home.nix` (see
[Pop!_OS with Nix](#popos-with-nix)).

- A listed package with no `dotfiles/<name>` directory is skipped with a
  warning; the other packages are still stowed.
- If the OS has no `dotfiles.txt`, `setup_dotfiles.sh` stops with an error and
  stows nothing.

Only the zsh package is split by OS:

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
3. Add the directory name to `lists/<os id>/dotfiles.txt` for each OS that
   should get it
4. Run `./scripts/setup_dotfiles.sh` to symlink them

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

> **Installing from URLs is currently switched off.** As before the move to a
> single branch, `scripts/install_from_urls.sh` only logs the tools it would
> install: the `install_from_url` call in `install_tools_from_urls` is commented
> out. Enabling it is a one-line change (uncomment that line).

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
files=(install.sh setup.sh lib/*.sh scripts/*.sh os/*/*.sh os/*/install_scripts/*.sh)
for f in "${files[@]}"; do bash -n "$f"; done
shellcheck "${files[@]}"
```

`nix flake check` evaluates and builds every Home Manager configuration for a
placeholder user (`checks.<system>.<os>`), so it needs neither `--impure` nor
a real home directory. Without Nix on the machine, run it in a container:

```bash
docker run --rm -v "$PWD":/src:ro nixos/nix sh -c '
  cp -r /src /work && cd /work && git config --global --add safe.directory "*" &&
  nix --extra-experimental-features "nix-command flakes" flake check -L'
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
`vault/` is gitignored, so copy it to the new machine manually.

### Restoring SSH and GPG Keys
To restore keys exported from another machine, use the `restore_ssh_key.sh` or `restore_gpg_key.sh` script. This script decrypts and reinstalls your private keys.

```bash
# Restore SSH key
./scripts/restore_ssh_key.sh
# Restore GPG key
./scripts/restore_gpg_key.sh
```

These scripts use paths relative to the current directory (`vault/`), so run
them from the repository root. They need `age`; on Pop!_OS Home Manager
installs it (`nix/common.nix`).

## Firstmate Backup (Optional)

`export_firstmate.sh` backs up the private files of the firstmate home
(`~/firstmate` by default) into one age-encrypted archive,
`vault/firstmate.tar.age`: `data/captain.md`, `data/projects.md`,
`data/learnings.md` (if it exists) and every file under `config/`. age asks for
a passphrase; it is never passed on the command line. This is a one-way
snapshot: firstmate keeps its files in its own home, so export again whenever
you want a fresh backup.

```bash
# Back up ~/firstmate (or $FM_HOME, or --home <dir>)
./scripts/export_firstmate.sh
# See which files would be backed up
./scripts/export_firstmate.sh --dry-run
```

`restore_firstmate.sh` decrypts the archive (age asks for the passphrase) and
puts the files back into the firstmate home, keeping their file modes. Clone
firstmate there first (on Pop!_OS `setup.sh` does that). An existing file that differs is first moved, with its
mode, into `data/.restore-backup-<timestamp>/<path>` in the firstmate home
(the export never archives it); identical files are left alone. `--dry-run` shows what would change.

```bash
./scripts/restore_firstmate.sh
```

`setup.sh` never runs the restore: run it by hand, from the repository root,
when you want the files back. Like the key scripts, both need `age`.
