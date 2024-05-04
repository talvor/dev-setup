#!/bin/bash

./scripts/install_packages.sh ./packages/host.txt

pip install --user ansible
export PATH=$PATH:~/.local/bin
