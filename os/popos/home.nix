# Pop!_OS: Home Manager on a non-NixOS system (the Nix counterpart of
# lists/popos/*.txt). Whatever needs root stays in ./prerequisites.sh.
{
  config,
  lib,
  pkgs,
  nixgl,
  ...
}:
let
  # Ghostty needs OpenGL, so its binaries are wrapped to start through nixGL
  wrappedGhostty = config.lib.nixGL.wrap pkgs.ghostty;
in
{
  targets.genericLinux = {
    enable = true;
    # Host-wide Nix graphics drivers (Mesa, plus a sudo setup step) are left
    # off: the one Nix GUI app here (Ghostty) is wrapped with nixGL instead
    gpu.enable = false;
    # nixGL gives a wrapped Nix GUI app Nix's own Mesa (config.lib.nixGL.wrap).
    # The default wrapper is "mesa" (nixGLIntel), which builds without --impure
    # and suits the Intel graphics in use.
    nixGL.packages = nixgl.packages;
  };

  home.packages = with pkgs; [
    # Terminal and AI
    claude-code
    codex
    herdr
    direnv
    wrappedGhostty

    # Dev tools
    lazygit
    lazydocker
    gh
    neovim

    # languages
    go

    # Utilities
    yubikey-manager
  ];

  # Launcher for the nixGL-wrapped Ghostty. It takes the place of the entry
  # the package ships, which is D-Bus activated and so depends on the session
  # bus finding the service file in the Nix profile.
  xdg.desktopEntries."com.mitchellh.ghostty" = {
    name = "Ghostty";
    genericName = "Terminal Emulator";
    comment = "A fast, feature-rich, and GPU-accelerated terminal emulator";
    exec = "${lib.getExe wrappedGhostty} --gtk-single-instance=true";
    icon = "com.mitchellh.ghostty";
    terminal = false;
    type = "Application";
    categories = [
      "System"
      "TerminalEmulator"
      "Utility"
    ];
  };

  # Other GUI apps stay Flatpaks: a Nix GUI app lacks the host graphics
  # drivers on a non-NixOS system unless it is wrapped with nixGL. nix-flatpak
  # installs them for this user from Flathub and leaves apps it does not
  # manage alone.
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
