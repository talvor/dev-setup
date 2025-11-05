# dev-setup

Automated Development setup using package manager and dotfiles management with GNU Stow.

## Features

- ✅ Install command line tools
- ✅ Install GUI applications
- ✅ Install fonts
- ✅ Install CLI tools from URLs (for tools not available via package manager)
- ✅ Setup dotfiles using GNU Stow
- ✅ Setup SSH and GPG keys from encrypted vault (optional)

## Prerequisites

- Supported OS (and package manager)
  - macOS (with Homebrew)
  - Fedora Linux (with DNF)
  - Arch Linux (with Pacman)
- Internet connection

## Quick Start

```bash
# Clone this repository
git clone https://github.com/talvor/dev-setup.git
cd dev-setup

# Make the main script executable
chmod +x setup.sh

# Run the complete setup
./setup.sh
```

## Manual Steps

You can also run individual setup steps:

```bash
# Install Prerequisites (if not already installed)
./scripts/install_prerequisites.sh

# Install command line tools
./scripts/install_tools.sh

# Install applications
./scripts/install_apps.sh

# Install fonts
./scripts/install_fonts.sh

# Install tools from URLs
./scripts/install_from_urls.sh

# Setup dotfiles
./scripts/setup_dotfiles.sh
```

## Customization

Edit the following files to customize what gets installed:

- `lists/tools.txt` - Command line tools
- `lists/apps.txt` - GUI applications
- `lists/fonts.txt` - Fonts  
- `lists/urls.txt` - CLI tools to install from URLs
- `dotfiles/` - Your personal dotfiles

## Structure

```
dev-setup/
├── setup.sh              # Main setup script
├── scripts/              # Individual setup scripts
├── lists/                # Lists of things to install
│   ├── tools.txt         # Homebrew CLI tools
│   ├── apps.txt          # Homebrew Cask applications
│   ├── fonts.txt         # Homebrew fonts
│   └── urls.txt          # CLI tools from URLs
├── dotfiles/             # Your dotfiles (managed by stow)
└── README.md             # This file
```

## Adding Your Own Dotfiles

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

The `lists/urls.txt` file allows you to install CLI tools directly from URLs. This is useful for:

- Tools not available via package managers
- Tools requiring direct installation from source
- Latest versions from GitHub releases

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
kubectl|https://dl.k8s.io/release/v1.28.0/bin/darwin/amd64/kubectl|binary

# Install Terraform from archive
terraform|https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_darwin_amd64.zip|archive
``` 
