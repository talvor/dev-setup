# Build the Home Manager configuration of one OS id: the shared modules plus
# os/<os>/home.nix.
{
  nixpkgs,
  home-manager,
  nix-flatpak,
}:
{
  os,
  system,
  username,
  homeDirectory,
  # Absolute path of the dev-setup checkout; the dotfile links point into it
  root,
}:
home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${system};
  modules = [
    nix-flatpak.homeManagerModules.nix-flatpak
    ./modules/dotfiles.nix
    ./modules/flatpak.nix
    ./common.nix
    (../os + "/${os}/home.nix")
    {
      home = { inherit username homeDirectory; };
      devSetup.root = root;

      # Nix is installed without channels, so point <nixpkgs> (nix-shell -p)
      # and the nixpkgs flake registry entry (nix shell nixpkgs#...) at the
      # nixpkgs pinned by flake.lock. keepOldNixPath is off because the
      # installer's default NIX_PATH names the missing channels directory.
      nix = {
        registry.nixpkgs.flake = nixpkgs;
        nixPath = [ "nixpkgs=${nixpkgs}" ];
        keepOldNixPath = false;
      };
    }
  ];
}
