#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install packages using apt
install_with_apt() {
    sudo apt update
    sudo apt install -y "$@"
}

# Function to install packages using dnf
install_with_dnf() {
    sudo dnf install -y "$@"
}

# Detect the package manager
if command_exists apt; then
    packageManager="apt"
elif command_exists dnf; then
    packageManager="dnf"
else
    echo "Unable to detect package manager"
    exit 1
fi

# Function to install packages based on the package manager
install_packages() {
    case "$packageManager" in
        apt)
            install_with_apt $(cat "$1")
            ;;
        dnf)
            install_with_dnf $(cat "$1")
            ;;
        *)
            echo "Unsupported package manager: $packageManager"
            exit 1
            ;;
    esac
}

# Check if the input file exists
if [ -f "$1" ]; then
    install_packages "$1"
else
    echo "Input file not found: $1"
    exit 1
fi
