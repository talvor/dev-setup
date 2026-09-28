# Home Manager settings shared by every OS in flake.nix (the Nix counterpart of
# lists/common/*.txt). OS specific settings go in os/<id>/home.nix.
{ lib, pkgs, ... }:
{
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "claude-code" ];

  home.packages = with pkgs; [
    # Command line tools
    tmux

    # Formerly installed from URLs
    starship
    claude-code

    # Needed by scripts/restore_{ssh,gpg}_key.sh
    age

    # Nerd Fonts
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.sauce-code-pro
    nerd-fonts.noto
  ];

  fonts.fontconfig.enable = true;
}
