# Development host setup

This setup installs most of the software that I use on my dev machine for web and software development.

## Installation

Download or clone this repository to your local drive.

```shell
$ cd ~
$ git clone https://github.com/talvor/dev-setup.git
```

## Setting up host

1. Install dependencies

   ```shell
   $ cd ~/dev-setup
   $ ./setup_fedora.sh
   $ cd ~/dev-setup/ansible
   $ ansible-galaxy install -r requirements.yml
   $ ansible-playbook setup_host.yml --ask-become-pass --ask-vault-pass
   ```

1. Restart your machine

