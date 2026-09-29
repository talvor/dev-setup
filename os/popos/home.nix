# Pop!_OS: Home Manager on a non-NixOS system (the Nix counterpart of
# lists/popos/*.txt). Whatever needs root stays in ./prerequisites.sh.
{ pkgs, ... }:
{
  targets.genericLinux = {
    enable = true;
    # Nix graphics drivers (Mesa, plus a sudo setup step) are only needed by
    # Nix GUI apps, and the GUI apps here are Flatpaks or apt packages
    gpu.enable = false;
  };

  home.packages = with pkgs; [
    # Terminal and AI
    claude-code
    herdr
    direnv

    # Dev tools
    lazygit
    lazydocker

  ];

  # GUI apps stay Flatpaks: Nix GUI apps lack the host graphics drivers on a
  # non-NixOS system. nix-flatpak installs them for this user from Flathub and
  # leaves apps it does not manage alone.
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      # Browsers
      "org.chromium.Chromium"

      # Development and AI
      "com.axosoft.GitKraken"
      "com.getpostman.Postman"
      "com.visualstudio.code"

      # Productivity
      "md.obsidian.Obsidian"

      # Utilities
      "com.dropbox.Client"
    ];
  };

  # dotfiles/ packages to link into $HOME (all of dotfiles/zsh/.zsh is linked;
  # ~/.zshrc sources ~/.zsh/popos.zshrc)
  devSetup.dotfiles = [
    "bash"
    "ghostty"
    "git"
    "gnupg"
    "nvim"
    "starship"
    "zsh"
  ];
}
